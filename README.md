# Radar Map

A north-up radar of the dungeon floor, for [Dungeon Rampage Haxe](https://github.com/Tutez64/Dungeon-Rampage-Haxe).

<!-- drh:show -->
A round radar in the top right corner. The camera of the game does not turn, so the map does not
either: north is always up and the arrow in the middle points the way your hero faces. The rooms
and the corridors of the floor are drawn as a map, the chests are blips on it, the enemies are red
dots, your party shows their hero face, and the exits are marked with the state of their gate.

- **Chests**: shows the treasure chests of the floor, each drawn as the chest it is: basic, uncommon,
  rare, legendary, or a small or royal item box.
- **Monsters**: shows the enemies on the floor.
- **Party**: shows the other heroes, with their picture.
- **Exits**: shows the exits and the state of their gates.
- **HUD**: shows the floor, the time, the gold and the experience under the radar.
- **Radius**: how big the radar is, in pixels. It starts at the smallest size, so it stays out of the
  way of the game's own hud.

The zoom keys are in **CONTROLS**: the bracket keys zoom in and out, from the whole floor down to
the room you are in.

The three keys of the mod are rebindable in the game's settings menu, at the end of **CONTROLS**:
**Show Radar** (`N` by default, shows or hides the radar), **Zoom In** (`[`) and **Zoom Out** (`]`).
Click the row and the game waits for the key you press.

Gate colors:

- Green: the exit is open.
- Orange: a plate to step on.
- Purple: monsters to kill.
- Cyan: a gate to break.
- Red: closed, and how to open it is unknown.
- Grey: not known yet.

If an exit is out of sight, a colored arrow on the rim points at it.

Chest colors:

- Wood: basic chest.
- Silver: uncommon chest.
- Gold: rare chest.
- Red with a fiery trim: legendary chest.
- Blue box: small item box.
- Purple box with gold ribbon: royal item box.
<!-- /drh:show -->

## How it reads the floor

The rooms come from the tiles the server laid out, with their open sides. The gate of an exit says
what it takes to open it, and the tile says whether it stands open now.

## Other automation

The other mods of the group do not conflict with this one.

## Data

The settings and the log live in `data/radarmap/`.

## License

MIT. See `LICENSE`.
