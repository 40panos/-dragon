<div align="center">

# 🐉 BBdragon

**A pixel-art dragon arcade game where every shot bounces, every boss fights back, and every dragon evolves.**

<img src="docs/media/promo.gif" alt="BBdragon gameplay trailer" width="360">

### [▶ Play it in your browser](https://40panos.github.io/-dragon/)
*Works on desktop and mobile — no install needed.*

![Godot 4.3](https://img.shields.io/badge/Godot-4.3-478cbf?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-7.5k%20lines-355570)
![Tests](https://img.shields.io/badge/tests-339%20passing-3fb950)
![Status](https://img.shields.io/badge/status-in%20active%20development-f0883e)

</div>

---

## What is this?

BBdragon is a **for-fun project I built to learn how far AI tools can take someone in a field they have never touched**. Before this I had never made a game — no engine experience, no pixel art, no animation. The goal was simple: use AI the way a professional would, as a set of tools I direct, review and push, and see how close I could get to a polished, *real-feeling* game.

Six weeks later it has four worlds, four evolving dragons, two dozen enemy types with their own abilities, multi-phase bosses, a bestiary, a soundtrack, an automated test suite and a browser build that deploys itself on every push.

**It is still very much a work in progress** — and I am enjoying every bit of it.

## The game

You are a dragon at the bottom of the screen. Aim, release, and watch a volley of projectiles bounce across the board. Enemies march down one row every turn; if they reach you, the run is over. Kill to charge your dragon's special, survive 20 rounds, and face the boss of each world.

| | |
|:--|:--|
| 🌍 **4 worlds** | Goblin Land, Frost Marches, Graveyard, Drowned Coast — each with its own floor, walls, weather, enemies and boss |
| 🐲 **4 dragons** | Ember (fire), Frost (ice), Death (souls) and the Fisher (sea), each with its own projectiles, special and an **evolved form** that takes over when the special fires |
| 👹 **28 creatures** | Riders that charge, knights with shields, warlocks that summon, wolves that hunt in packs, ghosts that shrug off weak hits, crabs, piranhas, jellyfish… |
| 💀 **6 bosses** | Including two 3×3 giants with phases: *Grukk's Siege Tower* throws barricades, war drummers and powder kegs; the *Ice Wendigo* freezes your shots in mid-air and shatters them |
| ✨ **Specials** | INFERNO (×3 damage), FREEZE (stop the world for 2 rounds), SWARM (a second full volley), HARPOON (spears pierce through everything) |

<div align="center">
<img src="docs/media/ember_inferno.png" width="190" alt="Ember's INFERNO">
<img src="docs/media/goblin_wave.png" width="190" alt="Riders charging, shield knights, warlocks summoning">
<img src="docs/media/siege_tower.png" width="190" alt="Grukk's Siege Tower">
<img src="docs/media/wendigo_frozen_gaze.png" width="190" alt="The Ice Wendigo freezing projectiles">
<br>
<img src="docs/media/death_swarm.png" width="190" alt="Death unmasked, SWARM">
<img src="docs/media/siege_boulder.png" width="190" alt="The siege boulder">
<img src="docs/media/angler_summon.png" width="190" alt="The Abyssal Angler and its brood">
<img src="docs/media/fisher_harpoon.png" width="190" alt="The Fisher's evolved form and HARPOON">
</div>

## How it was made — AI as a toolkit, me as the director

The interesting part of this project is not that AI was used, but **how**. I treated it like a small studio I was running:

- **Code — Claude Code (Anthropic)** as a pair programmer. I set the design, the rules and the quality bar; it wrote GDScript under them. Every feature lands with tests (339 of them), a real in-game screenshot check, and a descriptive commit — 85 commits so far.
- **Art — PixelLab** for pixel-art generation: enemies, bosses, dragons, tiles, walls, animations. Raw AI art is never good enough on its own, so most of the work was building a **pipeline around it** (`tools/`, 30 scripts) that turns generations into game-ready assets:
  - *Animation stabilizer* — re-aligns frames the model shifted by a pixel, restores untouched pixels and locks colors to the original palette. Idle loops went from 25–35% of pixels flickering between frames to 1–9%.
  - *Tone matching* — evens out tiles that came back in different brightness so floors don't look like a chessboard.
  - *Theme builders* — whole new world palettes (snow, graveyard, sea) generated from existing art by per-pixel recoloring, with deterministic snow, cobwebs and seaweed so animated frames never flicker.
  - *Grid extraction* — turns an upscaled screenshot of a hand-picked design back into clean pixel art.
- **Systems** — content is data-driven (Godot Resources): areas, enemies, dragons and abilities are composed without touching engine code. Abilities are modular hooks (charge, shield, summon, regenerate, pack, shatter…) that can be combined on a single enemy.
- **Production** — GitHub Actions runs the tests and publishes a web build on every push; this trailer was recorded frame-perfect with Godot's Movie Maker, staged by a script, and encoded by a small custom GIF encoder.

What I took away: AI is fast, but **taste, direction and verification are still the job**. Knowing what to ask for, spotting what's wrong, and building the checks that catch it is what turned generations into a game.

## What's next

- 🔁 **Roguelike runs** built around **dragon combinations**: elemental statuses (burn, chill, haunt, soaked), six cross-element reactions, allied dragons mixing their projectiles into your volley, and screen-clearing **Fusion specials**.
- 🌳 Small per-dragon skill trees and new projectile types.
- 🎵 More original music.
- 📱 A proper mobile release.

## Want to join?

If you came across this and it made you smile — **I'd be really glad to have company**. I'd especially love to hear from:

- 🎨 **Animators and pixel artists** — real hand-made animation would take this to another level.
- 💻 **Developers** — gameplay, Godot, tools, anything.
- 🎶 Musicians and sound designers.

Open an [issue](https://github.com/40panos/-dragon/issues) or reach out through my [GitHub profile](https://github.com/40panos). No experience requirements — this started as a learning project and it stays one.

## Credits

- 🎵 **Music** — composed by my friend **Theodoros Vakontios**. Thank you for giving the Goblin Land and the Graveyard their sound!
- 🎨 Pixel art generated with [PixelLab](https://pixellab.ai), directed and post-processed for the game.
- 🤖 Built with [Claude Code](https://claude.com/claude-code) by Anthropic.
- 🛠️ Made with the [Godot Engine](https://godotengine.org).

---

<details>
<summary><b>Run it locally / project layout</b></summary>

1. Install **Godot 4.3** (standard build).
2. **Import** → select `project.godot` in this folder → **F5**.
3. Tests: `godot --headless --path . --script tests/run_tests.gd`

| Path | What's there |
|---|---|
| `scripts/main.gd` | game flow: rounds, aiming, volleys, bosses, transitions |
| `scripts/entities/` | ball (projectile physics), block (enemy rendering & state) |
| `scripts/abilities/` | modular enemy abilities |
| `scripts/data/` | `AreaDef`, `EnemyType`, `DragonType` resources |
| `data/` | the actual content: areas (with their enemies) and dragons |
| `tools/` | the art pipeline and data writers |
| `tests/` | the automated test suite |

</details>
