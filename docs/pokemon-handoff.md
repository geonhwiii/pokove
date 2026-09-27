# Pokémon adventure — handoff

Replaces the fishing mini-game with a Pokémon collect-raise-battle game that runs on coding-agent
work. Keep this file current: it is what the next session (or a compacted context) reads first.

## Decisions (from the user, 2026-09-27)

- Real Pokémon via **PokéAPI at runtime**, like chattymin/PokeTokenBar: no Pokémon art or data is
  bundled in the repo or app. The data and sprites are downloaded and cached on the user's Mac. The README carries the
  unofficial, non-commercial fan-project disclaimer.
- The unique hook is **stage clearing** (like MapleStory Idle / Cookie Run): the party auto-battles
  through `world-stage` levels **while an agent works**. Bosses gate progress.
- **Party of at most 3.**
- **Encounters are fully random.** They are not tied to the tools used in a turn. Day/night or other
  tricks may come later.
- **Starter choice**: Bulbasaur / Charmander / Squirtle at Lv 5.
- Fishing is removed completely. Its data file `fishing.json` stays on disk untouched.
- Scope v1: Gen 1 (#1–151).

## Data sources

- One GraphQL request to `https://beta.pokeapi.co/graphql/v1beta` gets all 151 species (~150 KB,
  ~1.6 s). The query is in `PokeDexStore` and was tested with curl. language_id 3 is ko, 9 is en.
  `pokemon_v2_pokemonevolutions` on a species holds how it evolves *into* that species.
  Trigger 1 is level-up, 2 trade, 3 use-item. Species with `evolves_from` > 151 (Pikachu ← Pichu) count as
  base forms.
- Sprites come from `raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/`:
  - `versions/generation-vii/icons/{id}.png`: 40×30 box icon, used for the dex grid, party slots and
    the compact notch.
  - `versions/generation-v/black-white/animated/{id}.gif`: animated battle sprite with a cropped
    canvas (37–90 px). Shown at 1 device pixel per sprite pixel (0.5 pt on Retina). Bosses and
    the detail card use 1 pt.
  - `versions/generation-v/black-white/{id}.png`: 96×96 still, used as a fallback.
- Cache: `~/Library/Application Support/dancove/pokemon/` (`dex-v1.json`, `sprites/`). Game save:
  `adventure.json` (`adventure-debug.json` in Debug).

## Rules (v1, tune with scripts/adventure-sim.swift)

- **Stats:** HP = ⌊2·B·L/100⌋ + L + 10. Others = ⌊2·B·L/100⌋ + 5. No IVs, EVs or natures.
- **XP curve:** medium-fast (total XP = L³), max level 100.
- **Damage:** power 50, using the attacker's own type that is best against the target. STAB 1.5, the 18-type
  chart, 0.85–1 random, a 1/16 crit ×1.5. Physical or special depends on whether Atk ≥ SpA.
- **Evolution:** at `min_level`. Otherwise use-item → Lv 30, trade → 36, friendship/other → 22.
  Branching (Eevee) picks at random.
- **Encounter:** each finished agent turn ≥ 20 s rolls one wild species, weighted by capture rate and
  evolution stage (legendaries very rare). Capture chance is 0.55–0.9 by capture rate.
  - A new species joins the box.
  - A duplicate gives its owned copy XP.
  - Interrupted or failed turns get nothing.
- **Battle:** ticks about 1/s only while any agent is working. One action per tick, in speed order.
  - The party hits the front enemy; enemies hit a random party member.
  - HP carries across the waves of a stage and heals on clear. A wipe retries the stage, keeping the XP earned.
- **Stages:** world w, stage 1–10, endless. Enemy level ≈ 3 + 1.5 · globalIndex.
  - Normal stages have 3 waves of 1–2 enemies, generated with a seeded RNG, so a stage is always the same.
  - Stage 10 is a boss: one evolved species, +4 levels, ×2.5 HP. The first boss clear has a 60% chance to catch the boss.

## Tuning (scripts/adventure-sim.swift, 1.5 s per action, a turn every 4 min, 60% encounter)

- XP per knockout = baseExp × (1 + L/50) × 0.12 (×3 for a boss), for the whole party.
  - Catches arrive at the party's average level −8 ±2, and never below the level they evolve at.
  - A duplicate gives L² XP.
- After a wipe the party trains on the previous stage for 3 clears (`StageProgress`), so boss walls still earn
  XP.
- Result:

  | Agent work | Frontier stage |
  |---|---|
  | 0.5 h | 1-6 |
  | 1 h | 2-3 |
  | 4 h | 2-10 (boss wall) |
  | 8 h | 3-7 |
  | 16 h | 5-1 |
  | 32 h | 6-5 |
  | 64 h | 7-2 |
  | 96 h | Lv 100, then a wall around 15-1, because enemy levels cap at 96 |

  Post-100 content is phase 2.

## Architecture

| File | Role |
|---|---|
| `dancove/Adventure/PokeDex.swift` | `PokeType` (18, chart, colors, localized names), `PokeSpecies`, `PokeDexStore` (fetch + cache + load state) |
| `dancove/Adventure/PokeSprites.swift` | disk and memory sprite cache, GIF frame decoding, `PokeIcon` / `PokeSprite` views |
| `dancove/Adventure/BattleEngine.swift` | pure logic: stats, damage, stage generation, seeded RNG, XP |
| `dancove/Adventure/AdventureService.swift` | @Observable game state, agent-turn hooks, tick loop, persistence, banners |
| `dancove/Notch/Expanded/AdventurePageView.swift` | scene, party slots, dex grid, detail card, starter picker |
| `dancove/Settings/AdventureSettingsPane.swift` | toggles, reset, disclaimer |

Wiring: `ClaudeSessionStore` used to call `fishing.cast/nibble/reel/snap`. It now calls
`adventure.turnStarted/toolUsed/turnFinished/turnAborted`. `AppModel` sets
`adventure.isAgentWorking = { claude.isAnyWorking }`.

## Progress

- [x] Design agreed and sprite/data endpoints verified
- [x] PokeDex data layer + sprite cache (runs in the app; about 150 KB of dex JSON, sprites cached lazily)
- [x] Battle engine + simulation script, tuned (see "Tuning")
- [x] AdventureService (save, hooks, 1.5 s tick while agents work, encounters, evolution, boss joins, banners)
- [x] Adventure page UI (scene, party slots, dex grid, detail card, starter picker, loading and offline states)
- [x] Compact notch partner (`PartnerIcon`), banners (`CatchChip`, legendary celebration, `.adventure` style), menu bar "Open Pokédex"
- [x] Settings pane (`AdventureSettingsPane`), preferences (`adventureEnabled/AnnounceCatches/Sound`), debug verbs (`poke …`)
- [x] Fishing removed; `Color(hex:)` and `PixelSparkles` moved to `Shared/PixelSparkles.swift`
- [x] Localization (335 keys) + README section with disclaimer
- [x] QA: starter picker, battle scene, detail card, catch/legendary/evolution/boss banners, settings pane (all checked with screenshots)
- [x] Release installed to ~/Applications and committed locally (not pushed; push when the user asks)

## Ideas for phase 2

- Day/night encounter tricks (the user's idea). Shiny variants (`/shiny/` sprite paths). Items and a shop.
  Gens 2–5 (raise `PokeDexStore.maxID`; the query already takes it). Content after Lv 100: enemies cap at Lv 96.
- REST fallback if the GraphQL beta endpoint goes away.

## Testing

- Debug channel: `scratchpad/dbg <verb>` posts `com.geonhwiii.dancove.debug`. Verbs:
  `poke starter <id>`, `poke catch [id]`, `poke xp <n>`, `poke stage <w> <s>`, `poke tick <n>`,
  `poke reset`, `open adventure`, `select <dex number>`.
- `defaults write com.geonhwiii.dancove debugHoldOpen -bool true` stops outside clicks from closing the
  open notch. The user keeps working while tests run, and their clicks used to close it. Delete the
  default afterward.
- While any agent session is working (including the one running these tests), battles tick for real.
- Screenshots: `screencapture -x -o -l <window id>`. Get the window id from `scratchpad/winlist`.
- Never touch real agent session folders or the real clipboard in tests (see the memory file).
