# Changes: boss fix, spawn tables, kill-charged specials, dragon picker

**Audience:** the AI assistant working with @40panos on this repo.
**Written by:** the AI assistant working with @Tsarouchas (mechanics).
**Status:** done — on a branch with a PR. All 69 checks in `tests/run_tests.gd` pass.

Read this to explain to @40panos what changed, or before touching `main.gd`,
`hud.gd` or the data files. Nothing here touches the dragon's rendering
(`_draw_dragon()`, `mouth_pos()`, `tilt`, `recoil`), so the DragonView split in
`HANDOFF-dragon-view.md` is still valid as written.

---

## 1. Boss / area bug (fix)

**Before:** the round counter kept going while the boss was alive. At round 21 the
game switched to area 2 underneath the boss, so killing it later ran the reward code
for the wrong area — area 2 and the Frost dragon effectively never unlocked.

**Now:** while the boss is alive, `level` stays at 20. Every shot still ends a turn
normally: a new enemy row spawns, everything moves down, the boss summons. The turn
after the boss dies goes to round 21 / the next area.

- `main.gd` → `_end_turn()` only increments `level` when `not boss_alive()`.
- New helper `boss_alive()`.
- Side effects, both intended: rows spawned during the boss fight use round-20 HP,
  and Frost's `ball_every5` passive only counts real rounds (otherwise 20 % 5 == 0
  would give a free ball every shot).

## 2. Summons never land in the bottom rows

Warlocks and the boss could summon into row 10, which moved into the death row the
next turn — an unavoidable game over.

- `SummonerAbility` has a new `@export var max_row := 7`.
- `main.summon_minion()` takes `max_row` and only picks free cells in rows
  `min_row..max_row`. If those are full, the summon is skipped.
- The area `.tres` files don't set it, so they use the default 7.

## 3. Enemies unlock by round, with weighted spawn rates

`EnemyType` has two new fields: `min_round` (round *within the area* it can first
appear, 1 = from the start) and `weight` (relative spawn chance).
`AreaDef.pick(roll, area_round)` does a weighted pick among enemies whose
`min_round <= area_round`. `AreaDef.allowed(area_round)` returns that pool.
`main.area_round()` = `level - area_index * ROUNDS_PER_AREA`.

| Enemy | `min_round` | `weight` | Share once all unlocked |
|---|---|---|---|
| Goblin | 1 | 40 | 40% |
| Brute | 4 | 22 | 22% |
| Orc Rider | 6 | 16 | 16% |
| Shield Knight | 9 | 13 | 13% |
| Warlock | 9 | 9 | 9% |

The rounds count per area, so Frost Marches also opens with Goblins only (round 21).
Enemy HP still scales with the absolute round.

The `tier` field is still there but unused.

**Data duplication:** each enemy is defined in `data/enemies/*.tres` **and** copied as
a sub-resource into both `data/areas/*.tres`. Only the area copies affect gameplay.
All three were updated to stay in sync. Merging them so each enemy is defined once
would be a good cleanup.

## 4. Specials charge from kills, not damage

- `_on_ball_struck()` no longer adds damage to `special_charge`.
- `_on_block_damaged()` adds 1 per kill. Summoned minions and the boss count.
- New counter `main.kills` (reset per run).
- `special_cost` is now a number of kills: **Ember 15**, **Frost 18** (was 150 / 180
  damage). The default in `dragon_type.gd` is 15.
- The special button in the HUD shows `kills/cost` until it's ready.

### How the numbers were picked

`tests/balance_sim.gd` is a bot that plays the real game headless at high speed
(~1 game/second). It aims mostly at the lowest enemy and sometimes takes a random
angle, so it plays **worse than a human**. Treat the results as a lower bound.

```
godot --headless --fixed-fps 60 --script tests/balance_sim.gd -- runs=40 dragon=ember cost=15
```

Options: `runs`, `dragon` (id), `cost` (override the special cost), `seed`, and `flat=1`
(the old rules: all enemies from round 1, equal weights). **It writes to the player's
`save.json`, so back that up first.**

Results, 80 games each:

| Setup | Median death | Reached boss | Beat boss | First special |
|---|---|---|---|---|
| Old spawn rules, Ember 15 | round 13 | 3/80 | 0 | ~round 11 |
| New rules, Ember 15 | round 15 | 20/80 | 3 | ~round 11 |
| New rules, Frost 18 | round 18 | 30/80 | 3 | ~round 11 |

At cost 20, Inferno performed about the same as no special at all, which is why it
went down to 15. After the first charge it refills about every 4–5 rounds.

## 5. Runs restart from round 1; dragons unlock per run

- `_start()` always sets `area_index = 0`, `level = 1`. It no longer reads
  `unlocked_areas` from the save.
- `run_dragons: Array[String]` holds the dragons unlocked **in this run**.
  `_reset_dragons()` fills it with every dragon whose `unlock_after_area <= 0`.
- `_clear_area()` adds the dragons whose `unlock_after_area == area_index + 1` to
  `run_dragons`, sets `new_dragon = true` and announces it. It no longer switches
  dragon automatically and **no longer writes to the save**.
- The save still has `unlocked_areas`, `unlocked_dragons` and `selected_dragon` in
  `SaveManager.defaults()`, but nothing reads or writes them any more. Only
  `best_score` and `best_round` matter now. They can be removed with a save-version
  bump if you want.

## 6. Dragon picker UI

- **Button:** `dragon_rect()` is in the bottom bar, next to the ball count. It shows
  the current dragon's portrait and name, pulses orange with **NEW!** when
  `new_dragon` is set, and is greyed out when switching isn't allowed.
- **Picker:** tapping the button opens `picker_open`, a panel of cards in a 3-column
  grid. Unlocked cards show the special, its kill cost, `special_desc()` and
  `passive_desc()`. Locked cards show which area's boss unlocks them. The current
  dragon has an orange border. Tapping a card selects it; tapping outside closes.
- **Rules:** `can_switch_dragon()` = aim phase, not mid-drag, not paused.
  `select_dragon(id)` refuses locked dragons or switching at the wrong time.
  `special_charge` carries over when switching.
- **Layout and input** live in `main.gd`: `picker_panel_rect()`,
  `picker_card_rect(i)`, `picker_press(p)`. Drawing lives in `hud.gd`:
  `_draw_dragon_button()`, `_draw_picker()`, `_draw_portrait()`.
- **Portraits** use `DragonType.frame_for("aim", false, t)` tinted with `tint`, so
  they follow whatever art the dragon has.
- **Scaling:** cards are generated from `dragons`, so a new `.tres` in
  `data/dragons/` gets a card automatically. `unlock_after_area = 0` means it's
  available from the start. The grid fits **9 dragons**; more will need paging or
  scrolling (see the comment above `PICKER_COLS`).
- New `DragonType.special_desc()` / `passive_desc()`: add a `match` branch there
  when adding a new special or passive type.

---

## Tests

`tests/run_tests.gd` went from 38 to 69 checks. New ones cover: the boss surviving
several turns (round and area frozen, rows keep spawning, no free Frost balls); boss
kill unlocks Frost for the run; switching rules and picker taps; a new run resets to
round 1 with Frost locked; summon rows 2–7 only; kill-based charging; spawn pools per
round and weight ordering.

The summon check inside the boss test disables the boss's summons on purpose: a
minion landing in row 10 used to cause a game over mid-test. That can't happen any
more (see #2), but it keeps the test independent of luck.

```
godot --headless --script tests/run_tests.gd
```

Note: the test suite also writes to `save.json` (it saves `best_score = 4242`). That
was already true before these changes.

## Open issues / next steps

- **The boss is now the difficulty wall.** The bot beat it in 3 of 80 games. At round
  20 it has 280 HP and summons a Goblin every 2 turns with 35% of the boss's HP (about
  50–98 HP each, against about 14 for normal enemies at that round).
- Enemy data is defined in 3 places (see #3).
- Unused save fields (see #5).
- The picker holds at most 9 dragons.
