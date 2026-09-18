# Handoff: split the dragon's looks out of `main.gd`

**Audience:** the AI assistant working with @40panos on this repo.
**Written by:** the AI assistant working with the mechanics collaborator.
**Status:** proposal — read it all before changing anything.

---

## Why this exists

Two people work on this game. One does **art and animations**, one does **game
mechanics**. Right now `scripts/main.gd` is ~900 lines and contains *both* the game
logic *and* the dragon's rendering — `_draw_dragon()` plus the `tilt` and `recoil`
state variables.

That means every animation change and every balance change land in the same file, and
the two of us conflict on every single merge. This document describes the split we
agreed on, so both sides implement the same structure.

The `Animate the dragon from a 9-frame sheet` commit is a good example of the problem:
the frame playback itself landed cleanly in `dragon_type.gd`, but wiring it up still
required editing `main.gd` in two places — `mouth_pos()` and `_draw_dragon()`. After
this split, that same change would have touched only `dragon_view.gd`.

Nothing has been pushed except this file. Implement the change yourself, in this repo,
on a branch.

---

## The structure

Extract everything about how the dragon **looks** into its own node:

- `scripts/entities/dragon_view.gd` — a `Node2D`
- `scenes/dragon_view.tscn` — a scene wrapping that script

Follow the pattern this repo already uses in `scripts/fx.gd` and `scripts/hud.gd`: a
child `Node2D` that holds a back-reference `m` to main, reads state off it, and calls
`queue_redraw()` from `_process`.

**The view owns:**

- frame selection via `dragon.frame_for(phase, aiming, t)` — the ping-pong sheet
  playback added in `Animate the dragon from a 9-frame sheet` stays in
  `dragon_type.gd`; the view is simply the only caller of it
- the idle breathing bob and scale
- the tense shake while aiming
- head tilt smoothing toward the aim direction
- the recoil kick when a ball fires
- the muzzle glow
- the pixel-art placeholder fallback when no sprite is loaded
- the `tilt` and `recoil` variables, which get **deleted** from `main.gd`

**The view exposes:**

| Method | Purpose |
|---|---|
| `kick()` | main calls it the moment a ball is fired |
| `mouth_pos()` | where fire comes from; main delegates its own `mouth_pos()` here |
| `draw_height()` | so the mouth position and the drawing agree on sprite height |

**`main.gd` keeps all game logic** and only reports state the view reads: `phase`,
`aiming`, `aim_dir`, `t`, `launch_x`, `floor_y`. After this change `main.gd` must
contain no dragon drawing code at all.

Instantiate the view in `_ready()` **before** the blocks are spawned, so it keeps
drawing behind them, and below `fx` (which sits at `z_index` 50).

---

## Details that will bite you

- **`m` is untyped**, so `:=` type inference *fails* on anything read through it.
  Write `var kick_off: Vector2 = -m.aim_dir * recoil * 9.0`, not `var kick_off := ...`.
  This does not show up in the headless tests — it only appears when real frames render.

- **Code comments and doc-comments in this repo are Greek.** Match that. Commit
  messages are English. Match that too.

- **One visible change is expected:** the aim dots will now pass *behind* the dragon
  instead of over it, because a child node draws above the parent's own `_draw()`. If
  @40panos dislikes it, say so rather than silently working around it.

---

## Verify before claiming it works

Godot is not necessarily on `PATH` — use the full path to the executable.

1. Import assets — **required after anything adds a `.png`**, or textures fail
   silently at runtime:
   `<godot> --headless --path <project> --import`

2. Run the test suite (38 tests as of `Animate the dragon from a 9-frame sheet`, all
   passing):
   `<godot> --headless --path <project> --script tests/run_tests.gd`

3. **Render real frames.** The tests run headless and never call `_draw()`, so this
   step is not optional:
   `<godot> --path <project> --quit-after 240`
   Must produce zero `SCRIPT ERROR` / `ERROR` lines.

Then add tests guarding the new boundary — that the view node exists, that `main` no
longer has `tilt`/`recoil`, that `mouth_pos()` still sits above the floor, that
`kick()` charges the recoil, and that the view draws below `fx`. Keep everything green.

---

## How we work from here

**File ownership**

| Owner | Files |
|---|---|
| @40panos (art) | `art/*`, `scenes/dragon_view.tscn`, `scripts/entities/dragon_view.gd`, the sprite fields of `data/dragons/*.tres` |
| collaborator (mechanics) | `scripts/main.gd`, `scripts/core/*`, `scripts/abilities/*`, `data/enemies/*.tres`, the balance fields of `data/dragons/*.tres` |

**Rules**

- Branch names: `art/<thing>` and `mech/<thing>`. Small branches, merged often — do
  not let one sit for days.
- `scenes/main.tscn` is shared. Whoever touches it says so first. Godot rewrites node
  IDs and reorders nodes, so a conflict there usually cannot be resolved by hand.
- Run the test suite before every push.
- `data/dragons/*.tres` is the one file both sides edit. Sprite fields are art,
  `special` / `passive` / `special_cost` / `unlock_after_area` are mechanics.
- After every pull that adds art, re-run the import step. A stale import cache fails
  silently.

---

If you think any part of this split is wrong, push back before implementing it.
