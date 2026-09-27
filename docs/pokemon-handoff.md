# Pokémon adventure — handoff

Replaces the fishing mini-game with a Pokémon collect-raise-battle game that runs on coding-agent
work. Keep this file current: it is what the next session (or a compacted context) reads first.

## v2 direction (agreed with the user, 2026-09-27)

The user played v1 and found it flat. They didn't know why they were clearing stages, there was
nothing to do themselves, and every attack was the same tap. The loop below came out of a grilling
session. It supersedes the v1 rules further down wherever they differ.

**Goal: the Kanto journey.**
- Stages sit on a pixel map of Kanto made of real FireRed/LeafGreen places.
- There are 8 gyms, then the Elite Four and the champion.
- After the champion, Cerulean Cave (Mewtwo) opens. Past that the goal is the Pokédex; endgame content comes later.
- **Badges raise the level cap.** Experience past the cap is banked, not lost.
  - Gyms are the reason to push on.
  - Target pace: the first badge on day one, the champion in 3–4 weeks.
  - The user averages about 2.9 h of agent work a day, so that's roughly 40–60 h in total.

**Fuel.** Battles run only while Claude or Codex is working. No idle trickle.

**Battles: 1:1 relay.**
- One Pokémon per side, drawn large. When the active one faints, the party's next comes out, in the order the user sets.
- All three party members get experience.
- Pokémon use their real FRLG level-up moves, with Korean names from PokéAPI and Gen 3 power, accuracy and type.
- The AI picks the best move for the matchup.
- Strong moves have short cooldowns, so the moveset rotates.
- Effects: per-type visuals, crits, move names on screen, and "super effective" text.
- Status conditions are for later.

**Gyms.**
- Leaders are shown with their FRLG trainer sprites (Showdown), and they use their original teams.
- Their team and types show ahead of time, so party choice matters.
- An **AUTO** toggle (on by default) challenges gyms automatically. With it off, the party farms the stage before the gym until the user taps Challenge.
- A wipe costs nothing: the party trains on the previous stage, then retries.

**Getting Pokémon never fails and never stresses.** No Poké Balls and no failed catches. There are two ways to get one:
1. **Discovery.** A random wild Pokémon from the current area's real FRLG encounter table turns up about every 20 minutes of agent work, so about 8–10 a day.
   - It joins at once, with no queue to manage.
   - A new species gets a banner.
   - A duplicate gives its owned copy experience instead.
2. **Gacha, 3 cards, pick 1.**
   - Pulls cost coins, which only stage clears give, at about 2–3 pulls a day.
   - The three cards are face up and the user picks one, so there's no bad pull.
   - A duplicate card shows the experience it would give.
   - The pool is the species of every area reached so far, plus gacha-only species that unlock along the way: the other starters, Eevee, the fossils, Hitmonlee and Hitmonchan, Lapras, Porygon, and the trade Pokémon. Mew is very rare after the champion.

**Legendaries** are optional boss nodes on the map, and beating one means it joins:
- Snorlax on Route 12
- Zapdos at the Power Plant
- Articuno at Seafoam
- Moltres at Victory Road
- Mewtwo in Cerulean Cave

**Other.**
- Evolution happens at a level, as in v1. Stone and trade evolutions are mapped to levels, and Eevee branches at random. No evolution stones.
- Areas you've passed through can be revisited, to farm their Pokémon.

**UI (notch, about 520×180).**
- The left half is the always-visible battle, with the party bar underneath.
- The right half has tabs for Map, Pokédex and Gacha.
- Banners are only for big moments: a new species, a legendary, an evolution, a badge.
- Everything else, such as levels, moves and coins, goes into a "while you were away" recap when the page opens.
- A dot shows when a pull is ready.

**Save.** v2 starts fresh with a new starter choice and a new save file. The v1 `adventure.json` stays on disk untouched.

**Follow-ups from the user after trying v2 (same day):**
- Gacha as three Poké Balls, not cards. Picking one wiggles it and pops it open.
- The text strip mustn't cover the party's Pokémon.
- The tab icon is a Poké Ball.
- A one-click way to mute banners before screen sharing.
- The project may later be renamed **pokove**. Not now; noted under "Later".

## Standing decisions from v1

- Real Pokémon via **PokéAPI at runtime**, like chattymin/PokeTokenBar: no Pokémon art or data is bundled.
  Trainer teams, place names and badge names are hand-written game data in `Kanto.swift`, because PokéAPI has none.
  The README carries the fan-project disclaimer.
- **Party of at most 3.** Encounters are random, not tied to the tools used in a turn. Day/night tricks may come later.
- Starter choice: Bulbasaur, Charmander or Squirtle at Lv 5. Scope is Gen 1 (#1–151).

## Data sources

Three GraphQL requests go to `https://beta.pokeapi.co/graphql/v1beta`, run in parallel and cached in
`~/Library/Application Support/dancove/pokemon/`:

| File | Request | Size |
|---|---|---|
| `dex-v1.json` | species: names (language_id 3 = ko, 9 = en), types, stats, evolutions | ~150 KB, ~1.6 s |
| `moves-v1.json` | FRLG level-up learnsets (version group 7) plus each move's names, power, accuracy, type, priority and meta | ~115 KB, ~2.5 s |
| `encounters-v1.json` | FireRed/LeafGreen (versions 10 and 11) wild slots for the journey's location areas | ~200 KB, ~1.2 s |

Notes on the data:
- **Gen 3 move values:** PokéAPI keeps today's numbers. For each field, the first `pokemon_v2_movechanges` entry with version group > 7 (skipping 12 and 13, Colosseum/XD) holds the Gen 3 value. Damage class follows the type, as in Gen 3.
- **Korean names:** Kanto has no Korean location names in PokéAPI, so they're written by hand in `Kanto.swift`.
- **Sprites:**
  - Pokémon come from `PokeAPI/sprites`: Gen VII icons, and BW animated front and back sprites (`animated/back/{id}.gif`).
  - Items (`sprites/items/poke-ball.png` etc., 30×30) and badges (`sprites/badges/1…8.png`) come from the same repo.
  - Trainers come from Showdown: `play.pokemonshowdown.com/sprites/trainers/<name>-gen3.png`.

## Rules (v2; tune with scripts/adventure-sim.swift)

- **Journey:** `Kanto.main(starter:)` holds 27 nodes in FRLG order.
  - **Routes** have 2–4 stages. A stage has 2 wild Pokémon, 3 on the last stage of a route.
    - Species are drawn from the node's FRLG slots. Fishing and surfing count ×0.35 on land nodes.
    - Level is the node's range interpolated across its stages, capped at the party level −1. The last foe is at that level, the others 1–2 below.
  - **Gyms:** one trainer stage each. The **Pokémon League** has five: Lorelei, Bruno, Agatha, Lance and the rival.
  - Trainers bring the **last three** of their original team (`Trainer.battleTeam`).
  - **Legend nodes** (`Kanto.legends`) appear once the party reaches their `after` node. They are manual only, at 2.5× HP.
- **Level cap by badges:** 16, 23, 27, 32, 45, 47, 50, 54, then 65 with 8 badges, and 100 as Champion.
  - XP past the cap goes into `OwnedPokemon.banked`. A badge releases it.
- **Progress** (`JourneyProgress`):
  - The frontier advances on each first clear.
  - A route loss means 3 training clears on the previous wild stage.
  - The party **holds** on the previous wild stage before a trainer. AUTO challenges when the forecast is ≥ 50%, or ≥ 20% after 30 waiting clears. **Challenge** forces it. A trainer loss costs nothing.
  - **Stay** cycles the cleared stages of a reached route.
  - When everything is cleared, the party loops Cerulean Cave.
- **Battle** (`BattleState`, 1:1 relay):
  - Each round both actives choose a move. Order is by priority, then speed.
  - **Damage** is the Gen 3 formula: STAB 1.5, 2× crit (1/16, or 1/8 for high-crit moves), random 0.85–1.
    - Multi-hit uses Gen 3 odds; drain and recoil apply.
    - Immune means 0 damage. With no move that lands, the Pokémon uses Struggle, which is typeless here, with 25% recoil.
  - **Movesets** are the best four damaging moves learned by the current level (`PokeMove.rating`), at most two per type.
    - Excluded: self-KO, OHKO, sleep-only and state-dependent moves.
    - Fixed-damage moves are rated by equivalent power.
  - **Cooldowns:** power ≥ 60 rests 1 round, ≥ 75 rests 2, ≥ 95 rests 3; fixed-damage moves rest 1.
  - **AI:** party and trainers pick the best expected damage. Wild Pokémon pick at random 40% of the time.
  - HP carries through a stage and heals after it. All three party members get the XP.
- **XP per knockout:** `1.1 × √baseExp × (0.4 + 0.6 × min(1, foeLv/partyLv))`, ×1.5 from trainers, ×3 from legends. Curve L³.
- **Discovery:** each battle tick has a chance of 1.5 s / mean interval (6 min until you own 3 Pokémon, then 20 min). The species comes from the current route's pool, or the previous route's before a trainer.
  - It joins at 85% of the party level −1 ±2, at least at its evolve level, and at most the cap.
  - A duplicate evolution line gives its owned copy L² XP.
  - New species wait for the next "finished" banner, or get their own banner when no turn is tracked.
- **Gacha:** 400 coins buy three Poké Balls, drawn without replacement by rarity weight.
  - Weights: common 10, uncommon 5, rare 2.2, mythical 0.2.
  - Tiers come from the best encounter share: ≥ 15% common, ≥ 5% uncommon, rarer are rare. `Kanto.gachaOnly` species are rare; Mew is mythical after the Champion.
  - Owned lines weigh ×0.3, and ×0 on the first pull.
  - The ball kind shows the tier: Poké, Great, Ultra, Master.
  - A duplicate gives 2L² XP. A new journey starts with 400 coins.
- **Coins:** wild stage 2, trainer 30, legend 60.
- **Evolution** happens by level as in v1: item → 30, trade → 36, other → 22. Eevee branches at random.

## Tuning (scripts/adventure-sim.swift, 1.5 s per action, AUTO with the suggested party)

Champion times from six runs (three starters × two seeds), in hours of agent work:

| Milestone | Typical time |
|---|---|
| Boulder Badge | 0.5 h |
| Cascade Badge | 2–5 h |
| Thunder Badge | 3–8 h |
| Rainbow Badge | 6–8 h |
| Soul Badge | 10–18 h |
| Marsh Badge | 10–33 h |
| Volcano Badge | 12–33 h |
| Earth Badge | 17–40 h |
| **Champion** | **38–77 h** (median ~52 h, 3–4 weeks at the user's ~2.9 h/day) |

- **Gacha:** about 0.7 pulls per hour, so 2–3 a day.
- **Box:** about 40 species by 24 h and 60–68 by 48 h.
- **Wipes:** 17–55 in the first 24 h, almost all of them trainer attempts.

## Architecture

| File | Role |
|---|---|
| `dancove/Adventure/PokeDex.swift` | `PokeType`, `PokeSpecies`, `PokeDexStore` (downloads and caches species, moves and encounters), `PokeAPI.post` |
| `dancove/Adventure/PokeMoves.swift` | `PokeMove` (Gen 3 values, damage kinds, cooldown, rating), `MoveDex` (learnsets, movesets), the moves query |
| `dancove/Adventure/Kanto.swift` | trainers and teams, journey nodes, legends, towns, roads, level caps, gacha-only list, badge names, `EncounterDex` and its query |
| `dancove/Adventure/BattleEngine.swift` | `SeededRNG`, `PokeMath` (stats, XP), `GameData`, `DexView`, `Combatant`, `StagePlan`, `BattleState` (1:1 relay) |
| `dancove/Adventure/AdventureRules.swift` | `JourneyProgress`, `AutoChallenge`, `Forecast`, `Discovery`, `Gacha`, `Rewards`, `Recommend` |
| `dancove/Adventure/BattleText.swift` | battle messages with Korean particles (이/가, 을/를, 은/는) |
| `dancove/Adventure/AdventureService.swift` | game state, tick loop, growth, discovery, gacha, recap, banners, save (`adventure-v2.json`) |
| `dancove/Adventure/PokeSprites.swift` | sprite cache (Pokémon, back sprites, trainers, items, badges) and views |
| `dancove/Notch/Expanded/Adventure/` | `AdventurePageView` (layout, tabs, party bar, recap, dex, detail card), `BattleSceneView`, `MoveEffects`, `KantoMapView`, `GachaView` |
| `dancove/Shared/PixelSparkles.swift` | `PixelSparkles`, `PokeBallGlyph` (tab, settings and banner icon) |

## Progress (v2)

- [x] Direction agreed in a grilling session; data endpoints verified (moves, encounters, trainer, item and badge sprites)
- [x] Data layer (moves with Gen 3 values, encounters), journey data, rules, 1:1 battle engine
- [x] Sim rewritten and tuned (see "Tuning")
- [x] Service: journey, AUTO with forecast, discovery, Poké Ball gacha, level cap and bank, recap, banners, save v2
- [x] UI: battle scene (back sprites, plates, text strip, type effects), map with info cards, Poké Ball gacha, party bar with suggested team, recap card, bell toggle, Poké Ball tab icon
- [x] Menu bar "Adventure Banners" toggle, settings pane (AUTO, badges, journey, coins), Korean (363 keys)
- [x] QA with screenshots: routes, Brock fight and badge, gacha open, map card, recap, banners
- [ ] Release installed; commit and push when the user asks

## Later

- Status conditions (burn, paralysis, sleep), shown in the plates.
- Endgame after the Champion: a Battle Tower or gym rematches. The user said to decide after playing.
- Day/night encounter tricks, shiny variants, Gens 2+.
- Rename the project to **pokove** (the user's idea, not now).
- REST fallback if the GraphQL beta goes away.

## Testing

- Debug channel: `scratchpad/dbg <verb>` posts `com.geonhwiii.dancove.debug`. The verbs are listed in README → Building.
- `defaults write com.geonhwiii.dancove debugHoldOpen -bool true` keeps the notch open during screenshots. The user keeps working and clicking. Delete the default afterward.
- While any agent session works, including the one running tests, battles tick for real.
- Screenshots: `screencapture -x -o -l <window id>`. The notch is dancove's window at layer 27.
- `.task` timers must return when cancelled, `guard (try? await Task.sleep(...)) != nil`. `try?` alone runs the "timeout" code on cancel. That bug wiped the recap on reopen.
- Never touch real agent session folders or the real clipboard in tests (see the memory file).
