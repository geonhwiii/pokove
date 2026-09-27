// DancoveMediaRemote — a tiny bridge to the private MediaRemote framework.
//
// Since macOS 15.4, mediaremoted only answers now-playing queries from Apple-signed
// clients. The app therefore loads this library into /usr/bin/perl (see
// dancove-mediaremote.pl), which is allowed to talk to MediaRemote, and exchanges
// newline-delimited JSON with it over stdin/stdout.
//
// stdout: one JSON object per line
//   {"type":"state","playing":true,"title":"…","artist":"…","album":"…",
//    "duration":215.3,"elapsed":12.4,"timestamp":1727350000.12,"rate":1,
//    "pid":1234,"bundleId":"com.spotify.client","parentBundleId":null,
//    "artwork":"<base64>"|null (only present when the artwork changed)}
//   {"type":"empty"} when nothing is playing
// stdin: commands, one per line
//   "command <MRCommand id>"   e.g. 2 = toggle play/pause, 4 = next, 5 = previous
//   "seek <seconds>"
//   "refresh"
// The process exits when stdin reaches EOF, i.e. when the app goes away.

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <math.h>
#include <stdio.h>
#include <unistd.h>

typedef void (*MRRegisterFn)(dispatch_queue_t);
typedef void (*MRGetInfoFn)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*MRGetPIDFn)(dispatch_queue_t, void (^)(int));
typedef void (*MRGetIsPlayingFn)(dispatch_queue_t, void (^)(BOOL));
typedef void (*MRGetClientFn)(dispatch_queue_t, void (^)(id));
typedef Boolean (*MRSendCommandFn)(int, id);
typedef void (*MRSetElapsedFn)(double);

static void *mr;
static MRRegisterFn mrRegister;
static MRGetInfoFn mrGetInfo;
static MRGetPIDFn mrGetPID;
static MRGetIsPlayingFn mrGetIsPlaying;
static MRGetClientFn mrGetClient;
static MRSendCommandFn mrSendCommand;
static MRSetElapsedFn mrSetElapsed;

static NSString *lastArtworkSignature;
static BOOL refreshScheduled;
static NSMutableData *stdinBuffer;
// Held globally: a dispatch source is torn down as soon as its last reference goes away.
static dispatch_source_t stdinSource;
static dispatch_source_t parentWatchdog;

/// Leaves immediately, skipping atexit handlers that could wait on MediaRemote's threads.
static void quit(void) {
    fflush(stdout);
    _exit(0);
}

static void emit(NSDictionary *object) {
    if (![NSJSONSerialization isValidJSONObject:object]) return;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
    if (data == nil) return;
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static NSString *stringFromClient(id client, SEL selector) {
    if (client == nil || ![client respondsToSelector:selector]) return nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id value = [client performSelector:selector];
#pragma clang diagnostic pop
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static id orNull(id value) { return value ?: [NSNull null]; }

/// Numbers MediaRemote reports can be NaN or infinite (live streams); JSON can't carry those.
static id finiteOrNull(id value) {
    if (![value isKindOfClass:[NSNumber class]]) return [NSNull null];
    double number = [value doubleValue];
    return isfinite(number) ? value : [NSNull null];
}

static void publish(NSDictionary *info, BOOL playing, int pid, id client) {
    NSString *title = info[@"kMRMediaRemoteNowPlayingInfoTitle"];
    if (info.count == 0 || title.length == 0) {
        lastArtworkSignature = nil;
        emit(@{@"type": @"empty"});
        return;
    }

    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    state[@"type"] = @"state";
    state[@"playing"] = @(playing);
    state[@"title"] = title;
    state[@"artist"] = orNull(info[@"kMRMediaRemoteNowPlayingInfoArtist"]);
    state[@"album"] = orNull(info[@"kMRMediaRemoteNowPlayingInfoAlbum"]);
    state[@"duration"] = finiteOrNull(info[@"kMRMediaRemoteNowPlayingInfoDuration"]);
    state[@"elapsed"] = finiteOrNull(info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"]);
    state[@"rate"] = finiteOrNull(info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"]);
    NSDate *timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
    state[@"timestamp"] = [timestamp isKindOfClass:[NSDate class]]
        ? @(timestamp.timeIntervalSince1970)
        : @([NSDate date].timeIntervalSince1970);
    state[@"pid"] = @(pid);
    state[@"bundleId"] = orNull(stringFromClient(client, NSSelectorFromString(@"bundleIdentifier")));
    state[@"parentBundleId"] = orNull(stringFromClient(client, NSSelectorFromString(@"parentApplicationBundleIdentifier")));

    NSData *artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
    if ([artwork isKindOfClass:[NSData class]] && artwork.length > 0) {
        NSUInteger sampleLength = MIN(artwork.length, (NSUInteger)256);
        NSData *sample = [artwork subdataWithRange:NSMakeRange(artwork.length - sampleLength, sampleLength)];
        NSString *signature = [NSString stringWithFormat:@"%lu-%@", (unsigned long)artwork.length,
                               [sample base64EncodedStringWithOptions:0]];
        if (![signature isEqualToString:lastArtworkSignature]) {
            lastArtworkSignature = signature;
            state[@"artwork"] = [artwork base64EncodedStringWithOptions:0];
        }
    } else if (lastArtworkSignature != nil) {
        lastArtworkSignature = nil;
        state[@"artwork"] = [NSNull null];
    }
    emit(state);
}

static void refresh(void) {
    dispatch_queue_t queue = dispatch_get_main_queue();
    mrGetInfo(queue, ^(NSDictionary *info) {
        mrGetIsPlaying(queue, ^(BOOL playing) {
            mrGetPID(queue, ^(int pid) {
                if (mrGetClient != NULL) {
                    mrGetClient(queue, ^(id client) {
                        publish(info, playing, pid, client);
                    });
                } else {
                    publish(info, playing, pid, nil);
                }
            });
        });
    });
}

/// Coalesces bursts of MediaRemote notifications into a single query.
static void scheduleRefresh(void) {
    if (refreshScheduled) return;
    refreshScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        refreshScheduled = NO;
        refresh();
    });
}

static void handleCommand(NSString *line) {
    NSArray<NSString *> *parts = [line componentsSeparatedByString:@" "];
    if (parts.count == 0) return;
    NSString *verb = parts[0];
    if ([verb isEqualToString:@"command"] && parts.count > 1) {
        mrSendCommand(parts[1].intValue, nil);
    } else if ([verb isEqualToString:@"seek"] && parts.count > 1 && mrSetElapsed != NULL) {
        mrSetElapsed(parts[1].doubleValue);
        scheduleRefresh();
    } else if ([verb isEqualToString:@"refresh"]) {
        refresh();
    }
}

static void readStdin(dispatch_source_t source __unused) {
    char buffer[4096];
    ssize_t count = read(STDIN_FILENO, buffer, sizeof(buffer));
    if (count <= 0) {
        // The app quit or closed the pipe.
        quit();
    }
    [stdinBuffer appendBytes:buffer length:(NSUInteger)count];
    while (true) {
        NSRange newline = [stdinBuffer rangeOfData:[NSData dataWithBytes:"\n" length:1]
                                           options:0
                                             range:NSMakeRange(0, stdinBuffer.length)];
        if (newline.location == NSNotFound) break;
        NSData *lineData = [stdinBuffer subdataWithRange:NSMakeRange(0, newline.location)];
        [stdinBuffer replaceBytesInRange:NSMakeRange(0, newline.location + 1) withBytes:NULL length:0];
        NSString *line = [[NSString alloc] initWithData:lineData encoding:NSUTF8StringEncoding];
        line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (line.length > 0) handleCommand(line);
    }
}

static BOOL loadMediaRemote(void) {
    mr = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
    if (mr == NULL) return NO;
    mrRegister = (MRRegisterFn)dlsym(mr, "MRMediaRemoteRegisterForNowPlayingNotifications");
    mrGetInfo = (MRGetInfoFn)dlsym(mr, "MRMediaRemoteGetNowPlayingInfo");
    mrGetPID = (MRGetPIDFn)dlsym(mr, "MRMediaRemoteGetNowPlayingApplicationPID");
    mrGetIsPlaying = (MRGetIsPlayingFn)dlsym(mr, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    mrGetClient = (MRGetClientFn)dlsym(mr, "MRMediaRemoteGetNowPlayingClient");
    mrSendCommand = (MRSendCommandFn)dlsym(mr, "MRMediaRemoteSendCommand");
    mrSetElapsed = (MRSetElapsedFn)dlsym(mr, "MRMediaRemoteSetElapsedTime");
    return mrRegister && mrGetInfo && mrGetPID && mrGetIsPlaying && mrSendCommand;
}

static NSString *notificationName(const char *symbol) {
    CFStringRef *pointer = (CFStringRef *)dlsym(mr, symbol);
    if (pointer != NULL && *pointer != NULL) return (__bridge NSString *)*pointer;
    return [NSString stringWithUTF8String:symbol];
}

/// Entry point, invoked by perl as an XSUB. Never returns.
__attribute__((visibility("default")))
void dancove_stream(void) {
    @autoreleasepool {
        if (!loadMediaRemote()) {
            fprintf(stderr, "dancove: MediaRemote is unavailable\n");
            exit(2);
        }
        stdinBuffer = [NSMutableData data];

        mrRegister(dispatch_get_main_queue());
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        const char *names[] = {
            "kMRMediaRemoteNowPlayingInfoDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
            "kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
            "kMRMediaRemoteNowPlayingPlaybackQueueDidChangeNotification",
        };
        for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
            [center addObserverForName:notificationName(names[i])
                                object:nil
                                 queue:[NSOperationQueue mainQueue]
                            usingBlock:^(NSNotification *note) { scheduleRefresh(); }];
        }

        stdinSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, dispatch_get_main_queue());
        dispatch_source_set_event_handler(stdinSource, ^{ readStdin(stdinSource); });
        dispatch_resume(stdinSource);

        // Safety net: exit if the parent disappears without closing stdin.
        pid_t parent = getppid();
        parentWatchdog = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(parentWatchdog, dispatch_time(DISPATCH_TIME_NOW, 0), 5 * NSEC_PER_SEC, NSEC_PER_SEC);
        dispatch_source_set_event_handler(parentWatchdog, ^{
            if (getppid() != parent) quit();
        });
        dispatch_resume(parentWatchdog);

        refresh();
    }
    // MediaRemote delivers notifications via the main run loop, so dispatch_main() is not enough.
    CFRunLoopRun();
    quit();
}

/// Prints the current state once and exits; handy for debugging from a shell.
__attribute__((visibility("default")))
void dancove_get(void) {
    @autoreleasepool {
        if (!loadMediaRemote()) _exit(2);
        dispatch_queue_t queue = dispatch_get_main_queue();
        mrGetInfo(queue, ^(NSDictionary *info) {
            mrGetIsPlaying(queue, ^(BOOL playing) {
                mrGetPID(queue, ^(int pid) {
                    publish(info, playing, pid, nil);
                    quit();
                });
            });
        });
    }
    CFRunLoopRun();
    quit();
}
