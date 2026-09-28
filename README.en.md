# pokove

[한국어](README.md) · [Website](https://pokove.vercel.app/en/) · [Download](https://github.com/geonhwiii/pokove/releases/latest)

Your party travels in the MacBook notch while your agent works.

While Claude Code or Codex works, a Pokémon party in the notch rides through Kanto one station at a time. The notch also shows what your agents are doing and lets you answer Claude's permission requests without switching apps. Music, calendar, to-dos and clipboard history live there too.

![The adventure](docs/images/adventure.png)

## Install

1. Download `pokove.zip` from the [latest release](https://github.com/geonhwiii/pokove/releases/latest) and unzip it.
2. Move `pokove.app` to Applications and open it.

It runs on macOS 15 or later. Displays without a notch get a simulated one. When a new version is out, the notch's gear gets a dot and Settings › About links to it.

## Pokémon adventure

Your party holds up to three Pokémon. It only moves along the line while an agent works, on a journey through FireRed/LeafGreen's Kanto. Gyms and the Pokémon League are challenges of their own.

- **Starting out:** choose Bulbasaur, Charmander or Squirtle (Lv 5). Your first gacha pull is free.
- **The Challenge tab**
  - **Stages:** Kanto is thirty chapters, each a line of ten stations. Beat enough wild Pokémon at a station and the line moves on: a ring around the station fills with each win, and a full ring takes you to the next. Reaching a new station pays 20 stardust, clearing a chapter's last one 100. Wild Pokémon come at about the party's level. The last station has three, ending with a boss, the strongest one around, whose level doesn't follow the party's, so bosses grow toward each gym. Beat it and the line goes on to the next chapter. After a loss the party fights a few times at the station before, then tries again; **Next station** tries again right away. Chapters 28–30 open after the Champion. Stations hold the real wild Pokémon of their area. Tap a cleared station to go back to it.
  - **Gym:** every third chapter ends at a gym: clear chapter 3 to challenge Brock, chapter 6 for Misty, and chapter 27 for the Elite Four and the Champion. The VS screen shows their team, the badge at stake, the chance to win and the level that would win. You start each challenge yourself.
  - **Dungeons:** a stardust dungeon and an EXP dungeon. Stage 1 is one Lv 2 Pokémon and stage 2 two, so a lone starter can make a start; from stage 3 there are three, the last a boss. Each stage is two levels more.
    - Each dungeon has three tries a day. Clearing a new stage gives the try back; a loss uses one. When a stage is too much, spend what's left on your best stage for its reward again. Tries refill at 4:00.
    - The stardust dungeon changes type by weekday and pays an Ultra Ball the first time you clear every tenth stage. The EXP dungeon holds Normal and Fairy types and gives the whole party experience.
  - **Tower:** the Battle Tower opens after the Champion. Climb floor after floor until you lose; your best floor is kept.
  - Gyms, legendaries, dungeons and the tower play out once started, agent or not. Losing costs nothing.
- **The line under the tab** says what to do next: stations to the gym, the level that would beat it, and a shortcut (a dungeon, a pull).
- **Badges raise the level cap.** Experience past the cap is banked and comes back with the next badge.
- **Legendaries:** Snorlax, Zapdos, Articuno and Moltres wait on ★ branches of the line, and Mewtwo after the Champion. Beat one and it joins.
- **Battles** are a 1:1 relay, like the games, and every move has its own effect: fists, lightning, beams, quakes. Gen 3 power and accuracy, crits, multi-hits, drain and recoil, plus poison, burns and paralysis. The whole party shares the experience.

![The gym's VS screen](docs/images/gym.png)

### Getting Pokémon

Getting a Pokémon never fails.

- **Discovery:** about every 20 minutes of agent work, a Pokémon from the current area joins on the spot. One from a line you have gives experience instead.
- **Gacha:** 400 stardust opens one of three Poké Balls. A line you have gives experience instead. Every unevolved Pokémon is in it from the start, the other starters, Eevee, fossils and Lapras included, one to three levels under the party. Evolved forms come from evolving, legendaries from beating them at their ★, and Mew, very rarely, after the Champion.
- **Shinies:** 1 in 128 discoveries and gacha balls. A shiny from a line you have makes yours shine at its level.
- **Pokédex rewards:** an Ultra Ball for every ten species caught.

![The Pokédex and a Pokémon's card](docs/images/pokedex.png)

A Pokémon's card shows its next evolution, its next move, the experience left to the next level, the level cap and how it fares against the next boss. Pokémon you don't have yet show how to get them. Drag party slots to reorder them, or drag a Pokémon from the Pokédex onto a slot to swap it in. **Auto**, next to the party, sets up the best three for what's next.

![The gacha](docs/images/gacha.png)

### While you were away

If something big happened while the page was closed (a badge, a gym opening, an evolution, a newcomer, a lost boss fight), it shows as one line over the battle when you open it again. Everything is kept in the **history** (the clock next to the bell) for today and yesterday.

![While you were away](docs/images/away.png)

![The history](docs/images/history.png)

Banners only come for new species, evolutions, badges and legendaries. Mute them in one click with the bell on the page or **Adventure Banners** in the menu bar menu, say before sharing your screen.

> Unofficial, non-commercial fan feature. It is not affiliated with, endorsed, sponsored or approved by Nintendo, Game Freak, Creatures Inc. or The Pokémon Company. Pokémon and all related names, characters and images are their trademarks and copyrights.

## Agents

![The closed notch](docs/images/compact.png)

**No setup needed.** pokove follows the session files agents write as they work: `~/.claude/projects` covers the Claude desktop app, the CLI and IDE extensions, and `~/.codex/sessions` covers the Codex app and CLI. Toggle them in **Settings → Claude Code → Detection**.

- While an agent works, the closed notch shows its mark, your lead Pokémon and the elapsed time.
- Banners drop out of the notch when a turn finishes, needs permission or input, or fails. Click one to jump to that session's app.
- The Agents page shows only what's running or waiting for you: the current step, a timer, and permission requests with Allow / Always / Deny.

**Answering permissions from the notch** needs hooks. Open **Settings → Claude Code** and click **Install Hooks**.

- pokove adds small hooks to `~/.claude/settings.json`. Other settings and hooks are kept, and a backup is saved as `settings.json.pokove-backup`.
- The hooks forward each event to `127.0.0.1:47821` with `curl`, and do nothing if pokove isn't running.
- Restart any running Claude Code sessions so they pick up the hooks.
- If the app that runs Claude (Terminal, iTerm, VS Code, Claude desktop…) isn't in front, pokove holds the `PermissionRequest` hook and shows Allow / Deny in the notch. If you don't answer within the timeout (45 s by default), or you switch to that app, Claude asks in its own window as usual. If that app *is* in front, Claude's own prompt appears right away and the notch only shows a heads-up.
- A session disappears when its `claude` process exits. An Esc interrupt fires no hook, so pokove reads it from the session transcript instead. When a session reports through hooks, its file is ignored.

## More in the notch

- **Now Playing:** artwork (click it to open the source app), a scrubber, previous / play-pause / next and an output picker. When the track changes the notch briefly grows a line with the title. When audio moves to AirPods or a speaker, a card with its battery drops out of the notch (levels from `system_profiler`, no Bluetooth permission).
- **Calendar and to-dos:** today's events and a month grid, with a to-do list beside them, saved in `~/Library/Application Support/pokove/todos.json`.
- **Clipboard:** what you've copied (text, links, colors, images, files), newest first. Click to copy again, or paste straight into the app in front. Copies that password managers mark as confidential are never saved.
- **HUDs:** the volume and brightness HUD moves into the notch. Low battery at 20%, 10% and 5%.
- **Gestures:** swipe down on the trackpad to open, or to change pages while open; swipe up to close; swipe sideways to skip tracks.
- **Displays:** the notch appears on the built-in display or on every display. It can hide while an app is full screen, or from screen recordings.

The open notch shows one page at a time and reopens on the page you picked last; a Claude permission request comes first. The notch never takes keyboard focus from the app you're working in, except while you type a to-do; then key status goes back to your app.

## Permissions

| Feature | Permission |
|---|---|
| Replacing the volume / brightness HUD | Accessibility (Settings → Display & Sound → Grant…) |
| Pasting from the clipboard history | Accessibility (pokove presses ⌘V for you). Without it, items are only copied |
| Calendar page | Calendars (asked the first time you open it) |
| Now Playing | None: a tiny bridge loaded into `/usr/bin/perl` reads MediaRemote (see below) |

Once a day pokove asks GitHub's API for the latest release. Nothing about your Mac is sent.

pokove was called dancove until September 2026. On its first launch it copies dancove's settings and `~/Library/Application Support/dancove/` (saves, to-dos, clipboard history) and leaves the originals in place. macOS treats it as a new app, so grant Accessibility and Calendars again, and turn **Launch at Login** back on. Claude hooks installed by dancove keep working and show as outdated until you reinstall them.

## Data

- Species, FireRed/LeafGreen moves (with their status effects) and wild encounters come from three [PokéAPI](https://pokeapi.co) GraphQL requests.
- Sprites come from the PokéAPI sprite repository: Gen VII box icons, Black/White animated sprites (front, back and shiny), items and badges. Gym leader sprites come from [Pokémon Showdown](https://play.pokemonshowdown.com/sprites/trainers/).
- Everything is downloaded at runtime and cached in `~/Library/Application Support/pokove/pokemon/`. **No Pokémon assets are in the app or its code**, apart from the screenshots in this README.
- The save file is `adventure-v3.json` (`adventure-v3-debug.json` in Debug builds). On first launch it's migrated from v2's `adventure-v2.json`, which is left as it was, like v1's `adventure.json`.

## How it works

```
pokove/
  App/            AppDelegate (one notch window per display), AppModel (services), Preferences, LegacyMigration
  Notch/          NotchPanel (borderless, non-activating, above the menu bar)
                  NotchWindowController (positioning, hit-testing, hover, swipes)
                  NotchViewModel (open/hover state → NotchPresentation)
                  NotchLayout (sizes, radii, springs, transitions), NotchShape
                  Compact/ Banner/ Expanded/  (the views for each presentation)
  Services/
    Claude/       ClaudeHookServer (loopback HTTP), ClaudeSessionStore, ClaudeHookInstaller
    Agents/       AgentTranscriptWatcher (FSEvents over Claude Code and Codex session files)
    Updates/      UpdateChecker (GitHub's latest release)
    Todo/         TodoStore
    Media/        NowPlayingService, AudioOutputDevices, AudioRouteMonitor + BluetoothDeviceInfo (device card)
    HUD/          MediaKeyInterceptor (CGEventTap), SystemVolume (CoreAudio), DisplayBrightness
    Battery/ Calendar/ Clipboard/
  Adventure/      PokeDex (PokéAPI data + type chart), PokeMoves, PokeSprites (sprite cache, GIF frames),
                  BattleEngine (pure rules), AdventureRules, Kanto, BattleText, AdventureService
  Settings/       Sidebar settings window
MediaRemoteAdapter/
  PokoveMediaRemote.m, pokove-mediaremote.pl
```

- **The panel** has a fixed size and stays transparent. Only the SwiftUI content animates, so the window never resizes. It ignores the mouse unless the pointer is over the visible notch, so the menu bar underneath keeps working.
- **Now Playing:** since macOS 15.4, MediaRemote only answers Apple-signed clients. A build phase compiles `PokoveMediaRemote.m` into `libPokoveMediaRemote.dylib`, and the app runs it inside `/usr/bin/perl`. The bridge streams JSON lines on stdout and takes `command` / `seek` lines on stdin, following [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter).
- **Claude hooks** are `command` hooks that `curl` the event JSON to the app. They pass `__CFBundleIdentifier` and `$PPID` so pokove knows which app hosts each session.
- **The adventure's rules** and their tuning notes are in [`docs/pokemon-handoff.md`](docs/pokemon-handoff.md). `scripts/adventure-sim.swift` plays them for hundreds of simulated hours to tune the pacing.

## Website

`site/` is the landing page, built with [Astro](https://astro.build) and served from Vercel at https://pokove.vercel.app (Korean at `/`, English at `/en/`).

```bash
cd site && pnpm install && pnpm dev   # http://localhost:4321
```

- The hero is the app icon's pixel scene redrawn to fill the page, under a live notch that opens into the Adventure page. Its battle is scripted; the sprites load from PokéAPI's repository at runtime, like the app's, and none are in the repo.
- Copy for both languages lives in `site/src/i18n.ts`.
- Vercel deploys it on every push to `main`. The project `pokove` builds from the repo root, and `vercel.json` there installs and builds `site/` and serves `site/dist`.
- The download buttons point at `releases/latest/download/pokove.zip`.
- Headings use [Galmuri](https://github.com/quiple/galmuri) (SIL OFL, license next to the font) and body text uses Pretendard.

## Building

Open `pokove.xcodeproj` in Xcode 27 and run, or:

```bash
xcodebuild -project pokove.xcodeproj -scheme pokove -configuration Release -derivedDataPath build/DerivedData build
```

- `scripts/install.sh` builds Release, installs it to `~/Applications` and relaunches it.
- `scripts/package.sh` builds `build/pokove.zip` for a release and prints the `gh release create` command.
- `swift scripts/make-icon.swift` regenerates the app icon: a dark bezel around a pixel-art screen (a 44-cell grid, like a GBA scene) of dusk over a cove, with the notch, a stardust sparkle and a sail on the horizon. Pass a path to render a single 1024 px preview instead.

**Localization:** pokove follows the system language and ships in English and Korean. **Settings → General → Language** can override it (this needs a relaunch). Strings live in `pokove/Localizable.xcstrings` and `pokove/InfoPlist.xcstrings`. Battle, recap and guide lines that need Korean particles are built in `pokove/Adventure/BattleText.swift`. After adding UI text:

```bash
xcrun xcstringstool sync pokove/Localizable.xcstrings --stringsdata $(find build/DerivedData/Build/Intermediates.noindex/pokove.build -name '*.stringsdata' -path '*Debug*')
python3 scripts/localize-ko.py   # fills Korean; lists any key without a translation
```

**Debug channel:** Debug builds listen for `com.geonhwiii.pokove.debug` distributed notifications, which drive the notch from scripts. The actions are:

- **Notch:** `open media|calendar|todos|clipboard|claude|adventure`, `close`, `hover on|off`.
- **HUDs and activities:** `volume 0.5`, `brightness 0.5`, `charging`, `airpods` (connection card), `peek`, `banner`.
- **Media:** `media`, `toggle`, `next`.
- **Claude:** `allow`, `deny`.
- **To-dos:** `todo add <text>`, `todo type <text>`, `todo toggle`, `todo clear`, `keytest` (checks that key focus is lent and returned).
- **Clipboard:** `clip seed` (sample history), `clip clear`.
- **Windows:** `rebuild` (recreates the notch windows).
- **Adventure:**
  - Setup: `poke starter <id>`, `poke reset`, `poke champion`.
  - Progress: `poke catch [id]` (a discovery with a finished banner), `poke xp <n>`, `poke stardust <n>`, `poke shiny` (the leader shines), `poke jump <chapter> <station> <badges>` (1-based; station 11 means the line is cleared), `poke tick <n>` (battle actions without an agent or the clock).
  - Gacha: `poke pull`, `poke ultra` (adds an Ultra Ball), `poke ultraopen`, `poke open <ball>` (opens with the animation), `poke pick <index>`.
  - Battles: `poke challenge` (the boss), `poke legend <id>`, `poke dungeon stardust|experience [stage]` (the next stage, or the best one), `poke dungeonreset [stages]` (refills today's tries; `stages` also starts both climbs over), `poke tower`, `poke fx <move slug> [foe]` (plays a move's effect over the battle on screen).
  - Page: `poke pane challenge|dex|gacha|history|toast` (toast replays the newest history entry), `poke mode stage|gym|dungeon|tower|legend:<id>`, `poke badgebanner <n>`, `poke state` (writes to `$TMPDIR/pokove-state.txt`), `select <dex number>`.
- **Settings:** `settings claude|adventure|about|…`.

`defaults write com.geonhwiii.pokove debugHoldOpen -bool true` keeps the open notch up while you click elsewhere (for screenshots). `debugLatestVersion` pretends a newer release is out. `debugClaudeProjectsPath` and `debugCodexSessionsPath` point the session watcher at scratch folders, so simulated sessions never touch the real ones. `debugClipboardPasteboard` points the clipboard history at a named pasteboard, so tests never touch the real clipboard.

## Logos

The Claude mark is the official logo path from [Simple Icons](https://simpleicons.org) (`claude.svg`), drawn with a small SVG path parser (`Shared/SVGPath.swift`). The Codex mark is a vector redraw of the Codex app icon: a soft eight-lobed gradient cloud with a `>_` prompt. Both animate while their agent works. The logos are the trademarks of their owners.
