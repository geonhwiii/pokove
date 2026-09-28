# Pokémon adventure — handoff

Replaces the fishing mini-game with a Pokémon collect-raise-battle game that runs on coding-agent
work. Keep this file current: it is what the next session (or a compacted context) reads first.

## v3.3: bigger hits, move effects, two staged dungeons, an ungated line (agreed with the user, 2026-09-28)

Where this conflicts with v3.2 or earlier, v3.3 wins.

- **HP and damage ×10** (`PokeMath.hpFactor`) so hits read as more than a digit. Numbers pop in big and
  settle; critical yellow, super effective orange, resisted grey. Each hit of a multi-hit move shows its
  own number, and a knockout shows the whole blow (`BattleAction.strikes`), not the HP that was left.
- **Move effects by shape** (`MoveShape`, `MoveEffects.swift`): 17 shapes from the move's name (strike,
  blow, slash, lash, bite, stab, beam, stream, orb, volley, bolt, quake, wave, wind, drain, bind, storm)
  in the type's colors, with outlines so they read on every backdrop. Targets flash white and get
  knocked back; big or critical hits flash and shake the scene (off with Reduce Motion). HP bars and
  fainting wait a moment for the hit to land. `poke fx <slug> [foe]` plays one in the Debug build.
- **Recommend buttons removed** (the 👍 in the gym and legendary VS screens, the footer pill, the
  recap's best-team pill after three losses; `Losses.hintAfter`, `recap.stuck`, `hasBetterTeam` gone).
  The party bar keeps one button, **자동 / Auto** (`autoParty()`): the best three for the challenge
  underway, else the next boss, else simply the strongest. Neutral, never lit.
- **The line has no level gate.** "다음 역은 Lv N부터" read as odd, so stations no longer wait for the
  party's level. The user chose, over fixed-level walls (30% of fights lost in the sim) and keeping the
  gate quietly: wild levels stay at `min(station, party − 1)`, and stations then came to take a
  number of wins instead (below). A loss
  still means 3 clears at the station before; the footer says "4-8에서 연습 중" with **다음 역**, and
  the scene's top-right chip is now **다음 역 →** while repeating or training (`pushOn()`,
  `resumeJourney()`). The old "도전 N%" chip over the battle is gone; the gym tab's dot still says a
  gym is open.
- **Dungeons: 별의모래 던전 and 경험치 던전** instead of Easy/Normal/Hard (`DungeonKind`,
  `DungeonClimb`, `DungeonState`, `DailyDungeon`):
  - Stages 1–50 at Lv 3 + 2n (to 100), three foes each at −2, −1 and the stage level, the last a boss
    with 1.5× HP from the three strongest of the types in their most evolved form. Seeded by day, kind
    and stage, so a retry faces the same three.
  - Three tries a day each, refilled at 04:00. A try at the next stage that clears it gives the try
    back; a loss, or a go at the best stage again, uses one. Climbs keep their best stage across days.
  - Stardust dungeon: the weekday's types, 80 + 8n stardust a clear, an Ultra Ball on the first clear
    of every tenth stage. EXP dungeon: Normal and Fairy, a sixth of a level at the stage's level for
    each of the party (half a level made the Champion 40% sooner in the sim).
  - Recap lines per dungeon ("별의모래 던전 5단계 클리어", or "…3번 클리어") with the total paid.
  - The save writes `dungeons` (`DungeonState`); v1.2's `dungeon` day and recap `dungeon` tiers are
    ignored when read, and older builds read the new save fine (both are optional there).
- **Thirty chapters.** The line with no gate reached its last chapter in 1–8 h, so each of Kanto's ten
  legs (`Kanto.leg`, one gym to the next) is now three chapters of ten stations (`Kanto.chaptersPerLeg`):
  the same stretches and levels, split. The leg's boss is on its last chapter (3, 6, …, 24; the League
  on 27), its legendary on its first; 28–30 open with the Champion. The user wanted the chapter count
  up so the line doesn't sit on one chapter, and explicitly not new Pokémon tied to badges. Saves
  before v4 are split on load (`JourneyProgress.splitChapters(into:)`; the v2 migration too). The
  footer and the gym's lock count stations to the gym across chapters (`stationsToNextBoss`).
- **Stations take wins, termini are checkpoints.** Thirty chapters alone still let the ungated line
  reach chapter 27 in 1–8 h and loop there for 40 h, so each station now takes `Chapter.winsNeeded`
  wild Pokémon beaten (2.5 × its level, at least 3; `JourneyProgress.frontierWins`, optional in the
  save), shown as "12/40" in the footer. The terminus takes one win over its three, and its boss is at
  the station's level +2 whatever the party's (the others still follow the party), so the chapters
  before a gym build up to it; the user asked for gyms to come within reach gradually. Sim, six
  runs: badge 1 at 0.8–1.5 h, badge 4 at 8–13 h, badge 8 at 33–40 h, Champion at 48–61 h (all six), the
  line at chapter 27 by 45–50 h, 0–31 wipes, gyms mostly won on the first try (`SIM_WINS` sets the
  wins per level; 1.5 ended the line at ~33 h, 1.0 at ~24 h).
- **Sim** (`SIM_DUNGEON_XP` scales the EXP reward): each day climbs until a new stage beats the party,
  then spends the rest on its best stage. Six runs, 70 h: stardust dungeon ~570–880 a day; with the
  ungated line, Champion at 38–55 h in 5 of 6 runs (avg ~47 h; ~54 h with the gate, ~61 h+ before the dungeons),
  badge 4 at 2–8 h, the line at 9-10 by 1–8 h, 55–450 wipes. Reaching late areas early brings their
  species to discoveries and the gacha, which is most of the speed-up.

## v3.2: stages and gyms apart (agreed with the user, 2026-09-28)

The user found the balance off from the start: the line ran to its 10th station and then hit a gym
far stronger than anything on it, and the party sat there training. Decided in one Q&A round; where
this conflicts with v3.1 or v3 below, v3.2 wins.

- **The line never waits for a gym.** Clearing N-10 goes straight on to (N+1)-1, badges or not
  (`JourneyProgress.recordStation` → `moveOn`). Chapter 10 (Cerulean Cave) still opens with the
  Champion; until then a cleared chapter 9 loops.
- **The 10th station is a terminus:** three wild Pokémon in a relay, the last the strongest species
  in the stretch's pool (base stat total) two levels up (`StagePlan.station`, `lastStationFoes`).
  Drawn as a bigger dot; the gym terminal at the end of the line is gone.
- **Stations are level-gated.** Wild Pokémon still stay a level below the party, but the line only
  moves to the next station once the party's average level reaches that station's own level; until
  then it fights at the station before, which at a chapter's start is the previous chapter's 9th
  station, since the terminus is tougher (`previous`, `stationTarget(_:partyLevel:)`, `isReady`,
  `AdventureService.isHoldingBack`). The footer then says "다음 역은 Lv N부터", ahead of an open
  gym's hint. The line view follows the party, so it can show the chapter before the line's.
  *Found in the sim, not agreed up front:* with only the old "a level below the party" rule the
  free line reached 9-10 within 1–8 h and looped there for the rest of the game; with the stations'
  own levels and no cap the party lost thousands of times. The level gate gives: chapter 2 at ~2 h,
  4–5 at ~8 h, 6–7 at ~24 h, 8–9 at ~48 h, a handful of losses in total, badge N landing as the line
  reaches chapter N+1, Champion ~48–67 h with the sim's player (5 seeds). The level cap is what
  slows a party that skips gyms: chapter N+1's top level is about the cap with N badges.
- **Gyms are their own challenge.** Badge order is fixed; the next boss comes from the badges
  (`nextBoss`: first chapter whose badge isn't earned, then the League's five), and it opens once its
  chapter's line is cleared (`isBossOpen`). The League opens after chapter 9 with eight badges, and
  a win there goes straight on to the next of the five (`lineUp(goOn:)`).
- **AUTO is gone** (user: manual only). No training after a gym loss, no auto challenges; the
  AUTO toggle, its Settings switch and `poke auto` are removed. The save still writes
  `autoChallenge: false` so an older build can read it. Signals that a gym is waiting: a dot on the
  체육관 tab, the ⚡ 도전 N% chip on the battle, the footer's chance or level hint, and a history
  line "X 체육관이 열렸어요" / "포켓몬리그가 열렸어요" (`AdventureRecap.gymsOpened`, notable).
- **Migration:** on load a save whose line sat at N-10 waiting for its gym moves on to (N+1)-1
  with its training cleared (`moveOn` in `load()`); `retryLevel` is no longer read.
- **Sim:** the player takes a gym on at a ≥ 60% forecast, or hourly once the party is stuck at the
  cap. Run it as before; the knobs used for tuning were removed.
- **Card:** the level reads "Lv 5/16" (the cap after the slash, yellow at the cap) and the
  experience "EXP 19 남음", because two bare numbers side by side read alike.

## v3.1: guidance, history, richer Pokédex card (agreed with the user, 2026-09-27)

The user found the game hard to follow: what to do next, and why a boss keeps winning. The
"while you were away" panel also covered the battle every time the page opened. Decided in a Q&A
round with mockups; where this conflicts with v3 below, v3.1 wins.

- **Away recap → toast + history.** Opening the page moves the pending recap into the history at
  once (`takeRecap()`), so it never shows twice. Only big things (badge, evolution, newcomer, boss
  loss, dungeon clear: `AdventureRecap.isNotable`) get a one-line toast over the top of the battle
  for 4 s (longer while hovered); one item shows as its sentence, several as counts. Tapping it opens
  the history. Everything else only lights the dot on the **clock button** next to the bell.
- **History:** the clock button swaps the right pane for recaps grouped per absence, newest first
  ("방금 · 42분", "오후 10:11 · 1분", "어제 22:40 · 2시간"). Kept for today and yesterday (days turn at
  04:00 like the dungeon), at most 40 (`history`, `historyUnread` in the save).
- **Next step:** the stage line's footer is now a "what to do next" line: stations to the boss, resting
  until an agent works, the level that would beat the boss ("Lv 18이면 이길 확률 90%", or "상한 Lv 23이어도
  20%"), training progress, with one shortcut pill: the recommended team if it differs, today's
  easiest unclaimed dungeon, or the gacha.
- **Why a boss wins:** the gym VS screen adds a row above its bar with the level hint for the next boss
  ("Lv 28이면 63%"). `LevelHint` is the lowest level (everyone raised to it, evolving on the way)
  with a ≥ 60% forecast, by binary search up to the cap, computed off the main thread whenever the
  party, box or boss changes. Type advice ("풀 기술이 잘 먹혀요") was tried and dropped: the user wants
  players to work out matchups themselves.
- **Pokédex card:** next evolution (icon and level; silhouette and "???" until seen; Eevee shows
  "3가지 중 하나"), "상한 N" next to the level bar, the next move that will make the moveset, or at the cap
  how many levels the next badge releases, and a "X에게 유리/불리" pill against the next boss (no reason given).
  Species you don't have show where to meet them (`Guidance.habitats`: a chapter's stations, the
  gacha, a ★ legendary, Mew after the Champion, or evolving from another). Party actions moved to
  icons in the card's corner.
- **Recommend button:** the wand icon read as nothing, so it's now a labeled 👍 "추천" (party bar and VS
  bar) / "추천 팀" (footer, history). It turns yellow when the box holds a better team for the next boss
  (`hasBetterTeam`).

### Convenience (agreed 2026-09-28)

- *(Removed in v3.2 with AUTO.)* **AUTO fights with the best team.** When AUTO challenges a boss it swaps in `recommendedParty(for:)`
  first, and the team stays afterwards. It judges early retries by that team's chance
  (`bestReadiness`). A boss you start yourself keeps the party you set.
- **Drag and drop:** party slots reorder by dragging (swap places); an owned Pokémon dragged from the
  Pokédex onto a slot takes it (`place(_:at:)`). Payload is the owned Pokémon's UUID string.
- **Pokédex "보유만"** shows only species in the box (`@AppStorage("dexOwnedOnly")`).
- **Update check** (`UpdateChecker`): GitHub's latest release at launch and daily; a dot on the gear and
  a button in Settings › About. `defaults write com.geonhwiii.pokove debugLatestVersion 9.9` fakes one in
  Debug. No banner, by the user's choice. First release: v1.0.
- **Shiny Pokémon** (`Shiny`): 1/128 per discovery and per gacha ball (rolled when dealt). A shiny
  duplicate makes the owned one shiny at its level. Shiny BW battle sprites (`animated/shiny`,
  `animated/back/shiny`); box icons have no shiny art, so they get a `ShinyMark` ✦. A shiny partner
  sparkles when sent out; discoveries get the big celebration banner; the Pokédex counts them.
- **Status conditions** (`Ailment`): poison, burn and paralysis, from damaging moves' secondary chances
  (PokéAPI `movemeta.ailment_chance`, Gen 3 value from `movechanges.move_effect_chance` when it changed;
  cached as `moves-v2.json`). Both sides. Poison and burn take 1/8 max HP at the end of a round, burn
  halves physical damage, paralysis quarters speed and stops a move 25% of the time. Poison/Steel can't be
  poisoned, Fire can't be burned. Plates show 독/화상/마비. **Sleep isn't in**: no damaging move in
  Gens 1–3 puts the target to sleep, and the auto-battle only uses damaging moves. The user decided
  (2026-09-28) it isn't needed, so status moves stay out. Sim: champion median
  ~46 h (was ~53 h at HEAD before statuses, which matches the v3 table); dungeon Normal/Hard slightly
  harder. No retune.
- **EXP shown:** the card shows experience left to the next level ("869 남음", also on hover over party
  slots), and a knockout at a station pops "EXP +N" over the party's plate. Challenge EXP only lands on a
  win, so it isn't shown during the fight.
- **Pokédex rewards** (`DexRewards`): an Ultra Ball for every 10 species caught, paid once per
  milestone (`dexRewards` in the save; saves from before count from zero, so reached milestones pay
  on the next launch). The dex header shows the next milestone beside an Ultra Ball.
- **Battle Tower** (`BattleTower`, `TowerState`), after the Champion: a 타워 tab in 도전. Each floor is
  three fully evolved non-legendary Pokémon (base stat total ≥ 400) at Lv 50 + floor, seeded by week
  and floor. Winning climbs on at once (no VS card after floor 1, no result card between floors);
  a loss ends the run with a card ("N층을 넘지 못했어요 · 최고 M층"). +20 stardust a floor, an Ultra Ball
  every 10th, trainer-rate EXP on each floor won. AUTO never starts it; a run doesn't resume after
  relaunch.
- **Copy trimmed** at the user's request: no rules lines (the dungeon's floors, how to repeat a
  station, "수련하고 다시 도전해요" on the loss card and in the history, the gacha's "pick a ball" prompt); the history says where the party got to ("4-3에서 4-10까지 갔어요",
  "2-10에 머물렀어요") instead of battle counts.

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
- Effects: every move has a shape from its name (`MoveShape`: strike, blow, slash, lash, bite, stab, beam, stream, orb,
  volley, bolt, quake, wave, wind, drain, bind, storm) drawn in its type's colors, so each Pokémon's moves look like its
  own. Hits flash the target white and knock it back, big or critical ones flash and shake the scene (not with Reduce
  Motion), and each hit of a multi-hit move shows its own number. Numbers grow and turn orange (super effective) or
  yellow (critical).
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

## Rules (v3.2; tune with scripts/adventure-sim.swift)

- **Journey:** `Kanto.chapters(starter:)` holds 30 chapters of 10 stations (`Chapter.stationCount`), three per leg of Kanto (`Kanto.leg`, `Kanto.chaptersPerLeg`).
  - Stations take their wild pool and backdrop from a `Stretch` (FRLG areas); levels rise evenly across the chapter's range and are capped at the party level −1 when fought. One wild Pokémon a station; the 10th is a terminus with three, the last the stretch's strongest species at +2 (`StagePlan.station`).
  - There is no level gate (`JourneyProgress.stationTarget(_:)`): a station opens the next after `Chapter.winsNeeded` wild Pokémon beaten there (2.5 × its level); a terminus after one win, its boss at station level +2 regardless of the party.
  - Chapters 3, 6, …, 24 have a gym leader, chapter 27 the League (Lorelei, Bruno, Agatha, Lance, the rival); the others have none. The line doesn't wait for them: N-10 leads to (N+1)-1. Chapters 28–30 (Cerulean Cave) have no boss, open with the Champion, and the last loops.
  - Trainers bring the **last three** of their original team (`Trainer.battleTeam`).
  - **Legendaries** (`Kanto.legends`, `Chapter.legend`) are ★ branches on chapters 13, 16, 19, 25 and 28 (the first of their legs), open once the chapter is reached. 2.5× HP.
- **Level cap by badges:** 16, 23, 27, 32, 45, 47, 50, 54, then 65 with 8 badges, and 100 as Champion.
  - XP past the cap goes into `OwnedPokemon.banked`. A badge releases it.
- **Progress** (`JourneyProgress`): `chapter`, `station` (0–10; 10 only on the last open line, which loops), `boss` (League index), `training`, `repeating`, `cursor`, `badges`, `losses`.
  - A frontier clear advances the line. A loss on the line means 3 clears of the station before (`Losses.wildTraining`); **다음 역** (`pushOn()`) skips them, and stops a repeat.
  - The next boss follows the badges (`nextBoss`) and opens once its chapter's line is cleared (`isBossOpen`). The user starts every gym; a loss costs nothing and changes nothing but `losses`. A League win goes straight on to the next of the five.
- **Challenges** (`BattleTarget.isChallenge`: boss, legend, dungeon) play at 1 s per action regardless of agents; stations at 1.5 s only while an agent works. The service ticks every 0.5 s. XP from a challenge is held and granted only on a win.
- **Battle** (`BattleState`, 1:1 relay):
  - Each round both actives choose a move. Order is by priority, then speed.
  - **Damage** is the Gen 3 formula: STAB 1.5, 2× crit (1/16, or 1/8 for high-crit moves), random 0.85–1.
    - HP and damage are ten times the games' (`PokeMath.hpFactor`), so a hit is tens early and thousands late. Fixed
      damage (Sonic Boom, Seismic Toss) scales too; every ratio is as it was.
    - Multi-hit uses Gen 3 odds; drain and recoil apply.
    - Immune means 0 damage. With no move that lands, the Pokémon uses Struggle, which is typeless here, with 25% recoil.
  - **Movesets** are the best four damaging moves learned by the current level (`PokeMove.rating`), at most two per type.
  - **Cooldowns:** power ≥ 60 rests 1 round, ≥ 75 rests 2, ≥ 95 rests 3; fixed-damage moves rest 1.
  - **AI:** party, trainers and the dungeon pick the best expected damage. Wild Pokémon pick at random 40% of the time.
  - HP carries through a battle and heals after it. All three party members get the XP.
- **XP per knockout:** `1.1 × √baseExp × (0.4 + 0.6 × min(1, foeLv/partyLv))`, ×1.5 from trainers, ×3 from legends, ×1.25 in the dungeons. Curve L³.
- **Daily dungeons** (`DailyDungeon`): see v3.3 above. Stage n is Lv 3 + 2n; stardust 80 + 8n, an Ultra Ball (`Gacha.draw(floor: .rare)`) on the first clear of every tenth; EXP a sixth of a level at the stage's level. Three tries a day each; a new stage cleared gives its try back. Days turn at 04:00 local.
- **Discovery:** each station action has a chance of 1.5 s / mean interval (6 min until you own 3 Pokémon, then 20 min), from the current station's stretch.
  - It joins at 85% of the party level −1 ±2, at least at its evolve level, and at most the cap. A duplicate line gives its owned copy L² XP.
- **Gacha:** 400 stardust buy three Poké Balls, drawn without replacement by rarity weight (common 10, uncommon 5, rare 2.2, mythical 0.2).
  - Tiers come from the best encounter share of the stretches reached: ≥ 15% common, ≥ 5% uncommon, rarer are rare. `Kanto.gachaOnly` species are rare (unlocked by chapter); Mew is mythical after the Champion.
  - Owned lines weigh ×0.3, and ×0 on the first pull. A duplicate gives 2L² XP. A new journey starts with 400 stardust.
- **Stardust:** station +1, boss +30, legendary +60, the stardust dungeon by stage.
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
| `pokove/Adventure/AdventureRules.swift` | `StationPoint`, `BattleTarget`, `JourneyProgress` (+ v2 migration), `Losses`, `Forecast`, `Discovery`, `Gacha`, `Rewards`, `DungeonKind`, `DungeonClimb`, `DungeonState`, `DailyDungeon`, `Recommend`, `Guidance` (level hint, weaknesses, matchups, habitats, next move) |
| `pokove/Adventure/BattleText.swift` | battle, recap, challenge and guide (`GuideText`) lines with Korean particles (이/가, 을/를, 은/는, 로/으로, 이면/면) |
| `pokove/Adventure/AdventureService.swift` | game state, tick loop (stations on agent time, challenges on their own), growth, discovery, gacha and Ultra Balls, dungeon climbs, recap, banners, save (`adventure-v3.json`, migrating v2) |
| `pokove/Adventure/PokeSprites.swift` | sprite cache (Pokémon, back sprites, trainers, items, badges) and views |
| `pokove/Notch/Expanded/Adventure/` | `AdventurePageView` (layout, tabs, history button and pane, recap toast, party bar, dex, detail card), `ChallengeView` (mode picker, stage line, VS screens, dungeon cards, `StardustIcon`), `BattleSceneView` (scene, damage numbers, shake), `MoveEffects` (`MoveShape` and its painter), `GachaView` |
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

- Debug channel: `scratchpad/dbg <verb>` posts `com.geonhwiii.pokove.debug`. The verbs are listed in README.en.md → Building.
- To test the v2 → v3 migration on real data without touching the user's save: copy `adventure-v2.json` over `adventure-v2-debug.json` (back that up first), delete `adventure-v3-debug.json`, launch Debug.
- `defaults write com.geonhwiii.pokove debugHoldOpen -bool true` keeps the notch open during screenshots. The user keeps working and clicking. Delete the default afterward.
- While any agent session works, including the one running tests, battles tick for real.
- Screenshots: `screencapture -x -o -l <window id>`. The notch is pokove's window at layer 27.
- `.task` timers must return when cancelled, `guard (try? await Task.sleep(...)) != nil`. `try?` alone runs the "timeout" code on cancel. That bug wiped the recap on reopen.
- Never touch real agent session folders or the real clipboard in tests (see the memory file).
