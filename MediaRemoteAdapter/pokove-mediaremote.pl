#!/usr/bin/perl
# Loads libPokoveMediaRemote.dylib into this Apple-signed perl process and runs one of
# its entry points. MediaRemote answers perl, so the library can read now-playing info.
#
# Usage: pokove-mediaremote.pl <path to libPokoveMediaRemote.dylib> [stream|get]

use strict;
use warnings;
use DynaLoader;

my ($library, $function) = @ARGV;
die "usage: $0 <library> [stream|get]\n" unless defined $library;
$function //= "stream";
die "unknown function '$function'\n" unless $function eq "stream" || $function eq "get";

my $handle = DynaLoader::dl_load_file($library, 0)
  or die "failed to load $library: " . DynaLoader::dl_error() . "\n";
my $symbol = DynaLoader::dl_find_symbol($handle, "pokove_$function")
  or die "symbol pokove_$function not found\n";
DynaLoader::dl_install_xsub("main::run", $symbol);

$| = 1;
run();
