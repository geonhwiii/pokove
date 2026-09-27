# dancove

A Dynamic Island for the MacBook notch, modeled on [Alcove](https://tryalcove.com) with a few ideas from NotchNook. It also has coding agents built in: the notch shows what Claude Code (CLI, IDE or the Claude desktop app) and Codex are doing, tells you when they finish or need you, and lets you answer Claude's permission requests without switching apps.

## Features

### The notch
- A pure-black shape hugs the camera housing. It has concave "ears" that blend into the menu bar and continuous bottom corners.
- The notch morphs between states on springs converted from Alcove's own values (grow 150/20, shrink 175/17.5, hover 250/14, press 160/18).
- Hovering gives a small bouncy "breath" (1.075×) with haptic feedback, and pressing squeezes it to 0.94×.
- It opens on hover (the delay is adjustable) or on click. It closes when the pointer leaves or when you click elsewhere.
- Content blooms in from a blurred sliver, like Alcove.

### Live activities (closed notch)
| Activity | Left | Right |
|---|---|---|
| Now Playing | Album art (shrinks when paused) | Waveform tinted from the artwork |
| Now Playing + Claude working | Album art | Spinning Claude spark + waveform |
| Claude working | Spinning spark | Your lead Pokémon, hopping, + elapsed time for the turn |
| Claude needs you | Pulsing spark | ✋ (permission) / 💬 (input) |
| Charging | ⚡ Charging | Level + battery |
| Volume / brightness HUD | Icon + "Sound" / "Display" | Level bar with rubber-band overshoot |

- **QuickPeek:** when the track changes, the notch grows a line with a scrolling "♪ Title · Artist".
- **AirPods and speakers:** when audio moves to Bluetooth or AirPlay, a card drops out of the notch. The device (the right AirPods model, from its Bluetooth product ID) sits inside a ring whose glowing arc orbits while it connects. The arc then sweeps closed in green with a check and settles into a gauge of the lowest battery, while the left / right / case levels fade in one by one. The battery levels come from `system_profiler`, so no Bluetooth permission is needed.

### Open notch
There is one activity at a time, like Alcove. Swipe down or click the page icons to cycle through them. The notch reopens on the page you picked last. A Claude permission request still comes first, and Settings → General can switch this back to showing what's going on. The open notch is as wide as it needs to be, so every page icon (and its badge) stays clear of the camera housing.
- **Now Playing:** artwork (click it to open the source app), a thick scrubber with elapsed and remaining time, previous / play-pause / next, and an audio output picker.
- **Calendar:** weekday, a big date, and today's events, beside a month grid.
- **To-dos:** a minimal list right next to the calendar. The number of open items is shown large, like the calendar's date. Click **New To-do** and type; Return adds it and keeps the field open for the next one. Double-click an item to rename it, hover to delete it, and right-click for more. Checked items fill with a little bounce, then slide below the open ones. The list is saved in `~/Library/Application Support/dancove/todos.json`.
- **Clipboard:** what you've copied (text, links, colors, images, files), newest first. Click an item to copy it again, or hover it to paste it into the app in front, pin it, or delete it. Right-click for the same. Deleting the item that's on the clipboard clears the clipboard too. **Clear** takes a second click and keeps pinned items. Passwords and copies marked confidential (the nspasteboard.org markers that password managers use) are never saved. The history lives in `~/Library/Application Support/dancove/clipboard/`.
- **Adventure:** your Pokémon party battling through stages, and the Pokédex. See below.
- **Agents:** an at-a-glance status for Claude and Codex, laid out like the calendar. The number working is shown large. Beside it is only what's running or waiting for you (current step, timer, permission requests with Allow / Deny). When all is quiet it shows today's tally per agent and the last thing that finished. Idle sessions aren't listed. The status is the current tool ("Editing NotchView.swift"), thinking, waiting, done with duration, or failed. Pending permission requests sit on top with Allow / Always / Deny. Click a row to jump to the terminal or editor running that session.

### Notifications (banners that drop out of the notch)
- Claude finished (with project, duration and the final message), Claude needs permission or input, and Claude turn failed (rate limit, overload and so on).
- Low battery at 20%, 10% and 5%.
- Hovering a banner keeps it on screen. Clicking a Claude banner focuses that session's app.

### Displays
- The notch appears on the built-in display, or on every display if you choose. Displays without a notch get a simulated one.
- Optionally hide the notch while an app is full screen, or hide it from screen recordings.

### Gestures (trackpad)
- Swipe down to open, or to cycle activities while open. Swipe up to close.
- Swipe sideways to skip tracks.

## Pokémon adventure

While Claude or Codex works, your party of up to three Pokémon travels Kanto on its own: an idle stage game in the notch, in the spirit of MapleStory Idle or Cookie Run, on a journey through FireRed/LeafGreen's routes and gyms.

- **Starting out:** choose Bulbasaur, Charmander or Squirtle (Lv 5). You also start with one free gacha pull.
- **The journey** follows the real map: Route 1, Viridian Forest, Pewter Gym (Brock), Mt. Moon, … the eight gyms, Victory Road, the Elite Four and the Champion, then Cerulean Cave.
  - Each stretch holds two to four stages of wild Pokémon from its actual FRLG encounter table.
  - Gyms and the League are the walls: leaders bring the last three of their original team.
  - **Badges raise the level cap.** Experience past the cap is banked and flows back in at the next badge.
  - Optional legendaries sit on the map: Snorlax, Zapdos, Articuno, Moltres, and Mewtwo after the Champion.
- **Battles are a 1:1 relay**, shown like the games: the foe at the top right, your Pokémon from behind, info plates and a text box.
  - One action plays every 1.5 s, only while an agent works.
  - Pokémon use their real level-up moves with Gen 3 power, accuracy and type, and pick the best one for the matchup.
  - Strong moves rest for a turn or three, so movesets rotate. There are crits, multi-hits, drain and recoil, and pixel effects for each type.
  - When one faints, the next in the party comes out. All three share the experience.
- **AUTO** (on by default) takes on a gym once a forecast (24 simulated battles) puts the win chance at 50% or more. Until then the party trains on the last route. **Challenge** takes it on now. A loss costs nothing.
- **Getting Pokémon never fails:**
  - **Discovery:** about every 20 minutes of agent work, someone from the current area joins on the spot. A species you already have gives its line experience instead.
  - **Gacha:** coins from cleared stages buy three Poké Balls. The kind of ball hints at rarity. Open one and the Pokémon inside joins; a duplicate gives experience instead.
    - The pool is everything met on the journey, plus gacha-only Pokémon: the other starters, Eevee, fossils, Lapras and more. Mew appears after the Champion.
- **The page:**
  - The battle and your party are on the left, with a wand button for the best team against what's next.
  - The right side switches between the **Map** (tap a place for its Pokémon, trainer or legendary; stay on a route you've reached), the **Pokédex** and the **Gacha**.
  - "While you were away" sums up what happened since you last looked.
- **Banners** only come for new species, evolutions, badges and legendaries. Mute them in one click with the bell on the page or **Adventure Banners** in the menu bar menu, say before sharing your screen.
- **Data:** species, FireRed/LeafGreen moves and wild encounters come from three [PokéAPI](https://pokeapi.co) GraphQL requests.
  - Sprites come from the PokéAPI sprite repository: Gen VII box icons, Black/White animated sprites (front and back), items and badges. Gym leader sprites come from [Pokémon Showdown](https://play.pokemonshowdown.com/sprites/trainers/).
  - Everything is downloaded at runtime and cached in `~/Library/Application Support/dancove/pokemon/`. **No Pokémon assets are in this repository or the app.**
  - The save file is `adventure-v2.json` (`adventure-v2-debug.json` in Debug builds). The v1 `adventure.json` is left untouched.

`scripts/adventure-sim.swift` plays the rules for hundreds of simulated hours, to tune the pacing (see `docs/pokemon-handoff.md`).

> Unofficial, non-commercial fan feature. It is not affiliated with, endorsed, sponsored or approved by Nintendo, Game Freak, Creatures Inc. or The Pokémon Company. Pokémon and all related names, characters and images are their trademarks and copyrights.

## Logos

The Claude mark is the official logo path from [Simple Icons](https://simpleicons.org) (`claude.svg`), drawn with a small SVG path parser (`Shared/SVGPath.swift`). The Codex mark is a vector redraw of the Codex app icon: a soft eight-lobed gradient cloud with a `>_` prompt. Both animate while their agent works. The logos are the trademarks of their owners.

## Keyboard focus

The notch never takes keyboard focus from the app you're working in, except while you type a to-do. Then the panel (non-activating, so your app stays frontmost) becomes key. When you finish or the notch closes, key status goes back to your app.

## Localization

dancove follows the system language and ships in English and Korean. **Settings → General → Language** can override it (this needs a relaunch).

Strings live in `dancove/Localizable.xcstrings` and `dancove/InfoPlist.xcstrings`. After adding UI text:

```bash
xcodebuild -project dancove.xcodeproj -scheme dancove -derivedDataPath build/DerivedData build
xcrun xcstringstool sync dancove/Localizable.xcstrings --stringsdata $(find build/DerivedData -name '*.stringsdata' -path '*Debug*')
python3 scripts/localize-ko.py   # fills Korean; lists any key without a translation
```

## Claude Code and Codex integration

**No setup needed.** dancove follows the session files agents write as they work. `~/.claude/projects` covers the Claude desktop app, the CLI and IDE extensions, and `~/.codex/sessions` covers the Codex app and CLI. From these it shows the working indicator (with the right mark for each agent), finished and failed banners, and the adventure. Toggle them in **Settings → Claude Code → Detection**.

**Hooks** add the ability to answer Claude's permission requests from the notch, plus more precise states. When a session reports through hooks, its file is ignored.

1. Open **Settings → Claude Code** and click **Install Hooks**.
   - dancove adds small hooks to `~/.claude/settings.json`. Other settings and hooks are kept, and a backup is saved as `settings.json.dancove-backup`.
   - The hooks forward each event to `127.0.0.1:47821` with `curl`, and do nothing if dancove isn't running.
2. Restart any running Claude Code sessions so they pick up the hooks.

**Answering permissions from the notch:**
- If the app that runs Claude (Terminal, iTerm, VS Code, Claude desktop…) isn't in front, dancove holds the `PermissionRequest` hook and shows Allow / Deny in the notch.
- If you don't answer within the timeout (45 s by default), or you switch to that app, Claude asks in its own window as usual.
- If that app *is* in front, Claude's own prompt appears right away and the notch only shows a heads-up.

**Stuck sessions:** a session disappears when its `claude` process exits. An Esc interrupt fires no hook, so dancove reads it from the session transcript instead.

## Permissions

| Feature | Permission |
|---|---|
| Replacing the volume / brightness HUD | Accessibility (Settings → Display & Sound → Grant…) |
| Pasting from the clipboard history | Accessibility (dancove presses ⌘V for you). Without it, items are only copied |
| Calendar page | Calendars (asked the first time you open it) |
| Now Playing | None: a tiny bridge loaded into `/usr/bin/perl` reads MediaRemote (see below) |

## How it works

```
dancove/
  App/            AppDelegate (one notch window per display), AppModel (services), Preferences
  Notch/          NotchPanel (borderless, non-activating, above the menu bar)
                  NotchWindowController (positioning, hit-testing, hover, swipes)
                  NotchViewModel (open/hover state → NotchPresentation)
                  NotchLayout (sizes, radii, springs, transitions), NotchShape
                  Compact/ Banner/ Expanded/  (the views for each presentation)
  Services/
    Claude/       ClaudeHookServer (loopback HTTP), ClaudeSessionStore, ClaudeHookInstaller
    Agents/       AgentTranscriptWatcher (FSEvents over Claude Code and Codex session files)
    Todo/         TodoStore
    Media/        NowPlayingService, AudioOutputDevices, AudioRouteMonitor + BluetoothDeviceInfo (device card)
    HUD/          MediaKeyInterceptor (CGEventTap), SystemVolume (CoreAudio), DisplayBrightness
    Battery/ Calendar/
  Adventure/      PokeDex (PokéAPI data + type chart), PokeSprites (sprite cache, GIF frames), BattleEngine (pure rules), AdventureService
  Settings/       Sidebar settings window
MediaRemoteAdapter/
  DancoveMediaRemote.m, dancove-mediaremote.pl
```

- **The panel** has a fixed size and stays transparent. Only the SwiftUI content animates, so the window never resizes. It ignores the mouse unless the pointer is over the visible notch, so the menu bar underneath keeps working. It never takes key focus.
- **Now Playing:**
  - Since macOS 15.4, MediaRemote only answers Apple-signed clients. A build phase compiles `DancoveMediaRemote.m` into `libDancoveMediaRemote.dylib`, and the app runs it inside `/usr/bin/perl`.
  - The bridge streams JSON lines on stdout and takes `command` / `seek` lines on stdin. The approach follows [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter).
- **Claude hooks** are `command` hooks that `curl` the event JSON to the app. They pass `__CFBundleIdentifier` and `$PPID` so dancove knows which app hosts each session.

## Building

Open `dancove.xcodeproj` in Xcode 27 and run, or:

```bash
xcodebuild -project dancove.xcodeproj -scheme dancove -configuration Release -derivedDataPath build/DerivedData build
```

`swift scripts/make-icon.swift` regenerates the app icon: an Alcove-style dark bezel around a glossy screen with a dusk-over-the-cove mesh gradient, glass waves and the notch. Pass a path to render a single 1024 px preview instead.

Debug builds listen for `com.geonhwiii.dancove.debug` distributed notifications, which drive the notch from scripts. The actions are:

- **Notch:** `open media|calendar|todos|clipboard|claude|adventure`, `close`, `hover on|off`.
- **HUDs and activities:** `volume 0.5`, `brightness 0.5`, `charging`, `airpods` (connection card), `peek`, `banner`.
- **Media:** `media`, `toggle`, `next`.
- **Claude:** `allow`, `deny`.
- **To-dos:** `todo add <text>`, `todo type <text>`, `todo toggle`, `todo clear`, `keytest` (checks that key focus is lent and returned).
- **Clipboard:** `clip seed` (sample history), `clip clear`.
- **Windows:** `rebuild` (recreates the notch windows).
- **Adventure:**
  - Setup: `poke starter <id>`, `poke reset`.
  - Progress: `poke catch [id]` (a discovery with a finished banner), `poke xp <n>`, `poke coins <n>`, `poke jump <node> <stage> <badges>`, `poke tick <n>` (battle actions without an agent).
  - Gacha: `poke pull`, `poke open <ball>` (opens with the animation), `poke pick <index>`.
  - Battles: `poke challenge`, `poke legend <id>`, `poke auto on|off`.
  - Page: `poke pane map|dex|gacha|recap`, `poke badgebanner <n>`, `poke state` (writes to `$TMPDIR/dancove-state.txt`), `select <dex number>`.
- **Settings:** `settings claude|adventure|…`.

`defaults write com.geonhwiii.dancove debugHoldOpen -bool true` keeps the open notch up while you click elsewhere (for screenshots). `debugClaudeProjectsPath` and `debugCodexSessionsPath` point the session watcher at scratch folders, so simulated sessions never touch the real ones. `debugClipboardPasteboard` points the clipboard history at a named pasteboard, so tests never touch the real clipboard.
