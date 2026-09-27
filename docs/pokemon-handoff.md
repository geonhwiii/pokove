# Pokémon adventure — handoff

Replaces the fishing mini-game with a Pokémon collect-raise-battle game that runs on coding-agent
work. Keep this file current: it is what the next session (or a compacted context) reads first.

## v3 direction (agreed with the user, 2026-09-27)

After playing v2 the user found the small Kanto map hard to read and the gym challenge unexciting
("it doesn't feel like moving around a map anyway"). The map is gone; the right pane's first tab is
now **도전 (Challenge)** with three modes. Mockups were shown at the real 216×142 size.
Where this conflicts with v2 below, v3 wins.

**Only stages run on agent work.** Gym, League, legendary and dungeon battles start when tapped
(or when AUTO starts a gym) and play out with the current party whether or not an agent is working,
at 1 s per action. They keep going with the notch closed and land in the recap.
There is one battle at a time: a challenge interrupts the stage flow, which resumes afterwards.

**Stage mode: a subway line.**
- No place names on screen. The journey is **chapters** (1장 … 9장, then a post-game chapter),
  each a straight line of **10 stations** ending at the chapter's boss (badge terminal).
- Stations still use FRLG areas under the hood, for the backdrop and the wild Pokémon.
- Each station has **one wild Pokémon; the 10th has two**, so the whole journey has about as many
  fights as v2.
- Tapping a cleared station repeats it (replaces v2's "stay"); a button returns to the frontier.
- The current station shows the party leader hopping above it.
- Koga and Sabrina each get a chapter (Safari Zone before Sabrina).

**Gym mode: a VS screen.**
- Diagonal split: the party (leader's back sprite, party icons) on the left, the leader's FRLG
  sprite on a band of their type's color with speed lines on the right, the badge at stake in the
  middle, then the win chance and a glowing **도전!** button in the bottom bar.
- Locked until the chapter's 10 stations are cleared; the button then reads "N stations left",
  but the team and win chance are visible ahead of time. The League's five come one after another.
- **AUTO** (on by default): reaching the end of the line challenges the boss at once. A loss means
  training clears of the last station ("수련 중 4/30"), then another try. With AUTO off the party
  trains until **도전!** is tapped. *Tuned after agreement:* the agreed 10 clears made AUTO lose
  100+ times to the hard gyms in the sim, so training is up to 30 clears and ends early when a level
  gained gives at least a 15% forecast. The line shows the current win chance while training.
  After three losses to the same boss, the recap suggests the best-team button.
- Losing a challenge gives **no experience** (so battles that don't need agents can't farm);
  the party simply goes back to training on the stage line.

**Legendaries** are ★ branch stations on their chapter's line. Tapping one opens the same VS
screen; winning adds it to the party.

**Daily dungeon.**
- Easy / Normal / Hard around the party level, capped at the level cap. *Tuned after agreement:*
  −5 / ±0 / +5 with five fully evolved floors was too hard (Easy lost on day one), so the tier
  levels are −6 / −2 / +3 and the floors climb up to them.
- A **type of the day** by weekday: Mon grass, Tue fire, Wed water, Thu electric,
  Fri psychic and fighting, Sat rock and ground, Sun dragon and ghost.
- Five floors in one relay (HP carries over): four of the day's type, then a boss at +2 levels
  with twice the HP. A loss restarts from floor 1 and can be retried at once.
- Rewards once a day per tier: Easy 60 stardust, Normal 120 stardust, Hard an **Ultra Ball**
  (a gacha round whose balls are all rare or better), plus the experience earned inside on a win.
  A claimed tier shows "✓ 받음" until the reset at **04:00 local**. No carry-over, no streaks.
  AUTO never enters the dungeon.

**Currency: 별의모래 (Stardust)** replaces coins: 400 for three balls, +30 a boss, +60 a legendary.
A station pays +1 rather than v2's +2 a stage, because a station has one foe instead of two or three
(the same stardust per fight; +2 made pulls come twice as fast in the sim). The icon is PokéAPI's `stardust` item sprite, with a 3 pt gap
before the number.

**Save:** v3 reads `adventure-v3.json`, migrating from `adventure-v2.json` on first launch (badges,
box, stardust = coins, position mapped onto chapter/station). The v2 file is left as it was.

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
- The project was called **dancove** until 2026-09-27, when it was renamed **pokove** (bundle ID included). `LegacyMigration` copies the old settings and `Application Support/dancove/` on first launch.

## Standing decisions from v1

- Real Pokémon via **PokéAPI at runtime**, like chattymin/PokeTokenBar: no Pokémon art or data is bundled.
  Trainer teams, place names and badge names are hand-written game data in `Kanto.swift`, because PokéAPI has none.
  The README carries the fan-project disclaimer.
- **Party of at most 3.** Encounters are random, not tied to the tools used in a turn. Day/night tricks may come later.
- Starter choice: Bulbasaur, Charmander or Squirtle at Lv 5. Scope is Gen 1 (#1–151).

## Data sources

Three GraphQL requests go to `https://beta.pokeapi.co/graphql/v1beta`, run in parallel and cached in
`~/Library/Application Support/pokove/pokemon/`:

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

## Rules (v3; tune with scripts/adventure-sim.swift)

- **Journey:** `Kanto.chapters(starter:)` holds 10 chapters of 10 stations (`Chapter.stationCount`).
  - Stations take their wild pool and backdrop from a `Stretch` (FRLG areas); levels rise evenly across the chapter's range and are capped at the party level −1 when fought. One wild Pokémon a station, two at the 10th (`StagePlan.station`).
  - Chapters 1–8 end at a gym leader, chapter 9 at the League (Lorelei, Bruno, Agatha, Lance, the rival), chapter 10 (Cerulean Cave) has no boss and loops.
  - Trainers bring the **last three** of their original team (`Trainer.battleTeam`).
  - **Legendaries** (`Kanto.legends`, `Chapter.legend`) are ★ branches on chapters 5, 6, 7, 9 and 10, open once the chapter is reached. 2.5× HP.
- **Level cap by badges:** 16, 23, 27, 32, 45, 47, 50, 54, then 65 with 8 badges, and 100 as Champion.
  - XP past the cap goes into `OwnedPokemon.banked`. A badge releases it.
- **Progress** (`JourneyProgress`): `chapter`, `station` (0–10), `boss` (League index), `training`, `retryLevel`, `repeating`, `losses`.
  - A station clear advances the line. A loss on the line means 3 clears of the station before.
  - At the end of the line **AUTO** challenges the boss at once. A loss sets `training = 30` and `retryLevel = partyLevel + 1`; AUTO tries again when training is done, or earlier once the party reaches `retryLevel` with a forecast of at least 15% (`AutoChallenge.earlyRetryChance`). After 3 losses in a row the recap shows the best-team hint.
  - With AUTO off the party trains at the last station until **Challenge!**.
- **Challenges** (`BattleTarget.isChallenge`: boss, legend, dungeon) play at 1 s per action regardless of agents; stations at 1.5 s only while an agent works. The service ticks every 0.5 s. XP from a challenge is held and granted only on a win.
- **Battle** (`BattleState`, 1:1 relay):
  - Each round both actives choose a move. Order is by priority, then speed.
  - **Damage** is the Gen 3 formula: STAB 1.5, 2× crit (1/16, or 1/8 for high-crit moves), random 0.85–1.
    - Multi-hit uses Gen 3 odds; drain and recoil apply.
    - Immune means 0 damage. With no move that lands, the Pokémon uses Struggle, which is typeless here, with 25% recoil.
  - **Movesets** are the best four damaging moves learned by the current level (`PokeMove.rating`), at most two per type.
  - **Cooldowns:** power ≥ 60 rests 1 round, ≥ 75 rests 2, ≥ 95 rests 3; fixed-damage moves rest 1.
  - **AI:** party, trainers and the dungeon pick the best expected damage. Wild Pokémon pick at random 40% of the time.
  - HP carries through a battle and heals after it. All three party members get the XP.
- **XP per knockout:** `1.1 × √baseExp × (0.4 + 0.6 × min(1, foeLv/partyLv))`, ×1.5 from trainers, ×3 from legends, ×1.25 in the dungeon. Curve L³.
- **Daily dungeon** (`DailyDungeon`): tier level = party level −6 / −2 / +3 (Easy / Normal / Hard), capped at the level cap. Floors climb from tier level −3 to the tier level; the boss is tier level +1 with 1.5× (Easy) or 2× HP, one of the three strongest of the day's types in its most evolved form. Floors are seeded by day and tier, so a retry faces the same ones. Days turn at 04:00 local. Rewards: 60 / 120 stardust / an Ultra Ball (`Gacha.draw(floor: .rare)`).
- **Discovery:** each station action has a chance of 1.5 s / mean interval (6 min until you own 3 Pokémon, then 20 min), from the current station's stretch.
  - It joins at 85% of the party level −1 ±2, at least at its evolve level, and at most the cap. A duplicate line gives its owned copy L² XP.
- **Gacha:** 400 stardust buy three Poké Balls, drawn without replacement by rarity weight (common 10, uncommon 5, rare 2.2, mythical 0.2).
  - Tiers come from the best encounter share of the stretches reached: ≥ 15% common, ≥ 5% uncommon, rarer are rare. `Kanto.gachaOnly` species are rare (unlocked by chapter); Mew is mythical after the Champion.
  - Owned lines weigh ×0.3, and ×0 on the first pull. A duplicate gives 2L² XP. A new journey starts with 400 stardust.
- **Stardust:** station +1, boss +30, legendary +60, dungeon per tier.
- **Evolution** happens by level as in v1: item → 30, trade → 36, other → 22. Eevee branches at random.

## Tuning (scripts/adventure-sim.swift: stations 1.5 s per action on agent time, AUTO with the suggested party, challenges and the dungeon off agent time, 2.9 agent hours a day)

Six runs (three starters × two seeds), hours of agent work:

| Milestone | Typical time |
|---|---|
| Boulder Badge | 0.3–0.7 h |
| Cascade Badge | 2–4 h |
| Rainbow Badge | 3–8 h |
| Soul Badge | 7–15 h |
| Earth Badge | 15–26 h |
| **Champion** | **30–79 h** (median ~46 h, about 2–3 weeks) |

- **Boss tries:** 1–20 for the early gyms, 20–75 for Koga, Sabrina and the League (each a short off-agent battle).
- **Gacha:** about 0.8 pulls per hour of agent work (with the dungeon), so 2–3 a day. Box about 40 species by 24 h.
- **Dungeon:** Easy wins ~95%, Normal ~70%, Hard ~40% of days on the first two tries.

## Architecture

| File | Role |
|---|---|
| `pokove/Adventure/PokeDex.swift` | `PokeType`, `PokeSpecies`, `PokeDexStore` (downloads and caches species, moves and encounters), `PokeAPI.post` |
| `pokove/Adventure/PokeMoves.swift` | `PokeMove` (Gen 3 values, damage kinds, cooldown, rating), `MoveDex` (learnsets, movesets), the moves query |
| `pokove/Adventure/Kanto.swift` | trainers and teams, `Stretch`, `Station`, `Chapter`, `LegendSpot`, the chapters, level caps, gacha-only list, badge names, `EncounterDex` and its query |
| `pokove/Adventure/BattleEngine.swift` | `SeededRNG`, `PokeMath` (stats, XP), `GameData`, `DexView`, `Combatant`, `StagePlan` (station, boss, legend), `BattleState` (1:1 relay) |
| `pokove/Adventure/AdventureRules.swift` | `StationPoint`, `BattleTarget`, `JourneyProgress` (+ v2 migration), `AutoChallenge`, `Forecast`, `Discovery`, `Gacha`, `Rewards`, `DungeonTier`, `DailyDungeon`, `Recommend` |
| `pokove/Adventure/BattleText.swift` | battle messages with Korean particles (이/가, 을/를, 은/는) |
| `pokove/Adventure/AdventureService.swift` | game state, tick loop (stations on agent time, challenges on their own), growth, discovery, gacha and Ultra Balls, dungeon day, recap, banners, save (`adventure-v3.json`, migrating v2) |
| `pokove/Adventure/PokeSprites.swift` | sprite cache (Pokémon, back sprites, trainers, items, badges) and views |
| `pokove/Notch/Expanded/Adventure/` | `AdventurePageView` (layout, tabs, party bar, recap, dex, detail card), `ChallengeView` (mode picker, stage line, VS screens, dungeon, `StardustIcon`), `BattleSceneView`, `MoveEffects`, `GachaView` |
| `pokove/Shared/PixelSparkles.swift` | `PixelSparkles`, `PokeBallGlyph` (tab, settings and banner icon) |

## Progress (v3)

- [x] Direction agreed in a grilling session with mockups at real size (subway line, VS screen, dungeon, stardust)
- [x] Rules: chapters and stations, AUTO training with early retry, challenges off agent time, win-only challenge XP, daily dungeon, Ultra Ball, stardust, v2 save migration
- [x] Sim rewritten for chapters and the dungeon; retuned (station stardust 2 → 1, dungeon offsets, training 30 with early retry)
- [x] UI: Challenge tab (stage line with ★ branches, VS screens for bosses and legendaries, dungeon tiers), scene labels and training status, stardust purse, Ultra Ball button, recap hint; map removed
- [x] Korean (404 keys), README
- [x] QA with screenshots: migration of the real v2 save, line, VS, dungeon run, AUTO loss and training, legend branch, Ultra Ball round, recap
- [ ] Commit and push when the user asks

## Later

- Status conditions (burn, paralysis, sleep), shown in the plates.
- Endgame after the Champion: a Battle Tower or gym rematches. The user said to decide after playing.
- Day/night encounter tricks, shiny variants, Gens 2+.
- REST fallback if the GraphQL beta goes away.

## Testing

- Debug channel: `scratchpad/dbg <verb>` posts `com.geonhwiii.pokove.debug`. The verbs are listed in README → Building.
- To test the v2 → v3 migration on real data without touching the user's save: copy `adventure-v2.json` over `adventure-v2-debug.json` (back that up first), delete `adventure-v3-debug.json`, launch Debug.
- `defaults write com.geonhwiii.pokove debugHoldOpen -bool true` keeps the notch open during screenshots. The user keeps working and clicking. Delete the default afterward.
- While any agent session works, including the one running tests, battles tick for real.
- Screenshots: `screencapture -x -o -l <window id>`. The notch is pokove's window at layer 27.
- `.task` timers must return when cancelled, `guard (try? await Task.sleep(...)) != nil`. `try?` alone runs the "timeout" code on cancel. That bug wiped the recap on reopen.
- Never touch real agent session folders or the real clipboard in tests (see the memory file).
