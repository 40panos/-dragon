<div align="center">

# BBdragon

<img src="docs/media/promo.gif" alt="BBdragon gameplay" width="360">

**[Play it in the browser](https://40panos.github.io/-dragon/)** (desktop or phone, nothing to install)

</div>

## About

This is a for-fun project I started to learn how to use AI tools to get the best result I can in a field I had never touched. I had never made a game before. No engine experience, no pixel art, no animation. I wanted to see how far I could get if I treated the AI tools as tools: I decide what to build and how it should look, they help me build it, and I check and fix what comes out.

It's still ongoing and I keep adding to it.

## The game

It's inspired by the mobile game BBTAN. You aim, shoot a volley of bouncing projectiles and try to clear the enemies before they reach the bottom. In this version you play as a dragon, and the bosses fight back.

What's in it so far:

- 4 worlds: Goblin Land, Frost Marches, Graveyard and Drowned Coast, each with its own enemies, look and boss
- 4 dragons (fire, ice, death and a sea one), each with its own projectiles, a special move and a bigger evolved form
- 28 enemy types with different abilities: riders that charge, knights with shields, warlocks that summon, wolves that move in packs, ghosts that ignore weak hits
- 6 bosses, two of them big 3x3 ones with phases. The Siege Tower throws barricades, drummers and powder kegs at you, and the Ice Wendigo can freeze your shots in mid-air

<div align="center">
<img src="docs/media/ember_inferno.png" width="190" alt="Ember's special">
<img src="docs/media/goblin_wave.png" width="190" alt="Riders charging">
<img src="docs/media/siege_tower.png" width="190" alt="Siege Tower boss">
<img src="docs/media/wendigo_frozen_gaze.png" width="190" alt="Ice Wendigo">
<br>
<img src="docs/media/death_swarm.png" width="190" alt="Death dragon">
<img src="docs/media/siege_boulder.png" width="190" alt="Siege boulder">
<img src="docs/media/angler_summon.png" width="190" alt="Abyssal Angler">
<img src="docs/media/fisher_harpoon.png" width="190" alt="Fisher dragon">
</div>

## How I made it

- **Code:** written in Godot (GDScript) with Claude Code as a coding assistant. I made the design decisions and reviewed the changes. There are 339 automated tests, and every push builds and publishes the browser version through GitHub Actions.
- **Art:** the sprites, tiles and animations started as PixelLab generations. Most of them needed cleanup before they looked right in the game, so I built a set of scripts in `tools/` to fix them. These scripts:
  - stop animation frames from flickering
  - even out tile colors so the floors don't look like a chessboard
  - recolor existing art into new themes (snow, graveyard, sea)
- **Content:** worlds, enemies, dragons and abilities are defined as data, so adding a new enemy or ability doesn't mean rewriting the game code.

## What's next

- Turning it into a roguelike where you combine dragons and their abilities into combos
- Small skill trees and more projectile types
- More music
- A proper mobile release

## Want to help?

If you find this and want to work on it with me, I'd be really happy to hear from you, especially if you're an animator or pixel artist (real hand-made animation would make a huge difference) or a developer. Musicians and sound designers are welcome too.

Open an [issue](https://github.com/40panos/-dragon/issues) or message me through my [GitHub profile](https://github.com/40panos).

## Credits

- Music by my friend **Theodoros Vakontios**, who made the Goblin Land and Graveyard tracks. Thank you!
- Pixel art generated with [PixelLab](https://pixellab.ai) and cleaned up for the game
- Coding assistance from [Claude Code](https://claude.com/claude-code)
- Made with [Godot](https://godotengine.org)

<details>
<summary>Running it locally</summary>

1. Install Godot 4.3.
2. Import `project.godot` from this folder and press F5.
3. To run the tests: `godot --headless --path . --script tests/run_tests.gd`

Main folders: `scripts/` (game code), `data/` (worlds, enemies, dragons), `tools/` (art scripts), `tests/`.

</details>
