# zig-rl

A small turn-based roguelike scaffold in Zig. The first playable slice runs in a native desktop window and keeps the game logic deterministic and separate from rendering.

The project follows the shape of zig-gamedev sample apps where it helps: build steps are exposed through zig build -l, the executable has a run step, and zgd-style aliases such as roguelike-run and roguelike-test are available. Rendering uses zig-gamedev packages so the game opens as a real desktop window instead of an ASCII terminal.

## Requirements

- Zig 0.16.0 or newer.
- zig-gamedev packages fetched by Zig's package manager: zglfw, zopengl, and zgui.

Install Zig with your preferred package manager. On this machine, Homebrew provides it:

    brew install zig

## Build

    zig build

List available steps:

    zig build -l

Run tests:

    zig build test

## Run

    zig build run

The zgd-style sample alias also works:

    zig build roguelike-run

For automated verification, this opens the native window briefly and exits:

    zig build run -- --smoke-test

Controls:

- WASD, HJKL, or arrow keys: move one tile.
- . or space: wait one turn.
- q or Escape: quit.

## Project Layout

    .
    |- build.zig
    |- build.zig.zon
    |- README.md
    |- assets/
    |  |- config/
    |- docs/
    |  |- goal.md
    |- src/
    |  |- main.zig
    |  |- app.zig
    |  |- game.zig
    |  |- state.zig
    |  |- input.zig
    |  |- render.zig
    |  |- window.zig
    |  |- config.zig
    |  |- root.zig
    |  |- world/
    |  |  |- map.zig
    |  |  |- generation.zig
    |  |  |- tile.zig
    |  |- entities/
    |  |  |- entity.zig
    |  |  |- player.zig
    |  |  |- enemy.zig
    |  |- systems/
    |  |  |- turn.zig
    |  |  |- movement.zig
    |  |  |- combat.zig
    |  |- ui/
    |     |- hud.zig
    |     |- log.zig
    |- tests/
       |- simulation.zig

## Architecture Notes

- src/state.zig owns deterministic simulation data: map, player, enemies, turn count, and messages.
- src/world/ owns tile storage, collision helpers, and starter dungeon generation.
- src/systems/ mutates state through small rules such as movement and turn advancement.
- src/render.zig owns testable render layout values and does not decide game rules.
- src/window.zig owns the zglfw native window, keyboard polling, zgui UI, and draw-list rendering.
- src/input.zig defines command parsing for shared input semantics.
- assets/ and assets/config/ are placeholders for later art, tilesets, palettes, tuning files, and generated data.

## Current Playable Slice

- Deterministic starter dungeon with boundary walls, two rooms, and corridors.
- Player movement on a grid.
- Wall collision.
- Turn advancement after valid movement or waiting.
- Message log with bounded retention.
- Enemy placeholders rendered on the map.
- zig-gamedev native window with colored tiles, zgui HUD, and message panel.
- Simulation tests for map generation, movement, turn progression, and log retention.

## Next Milestones

### Enemies

Add enemy turns in src/systems/turn.zig. Keep them deterministic by iterating state.enemies[0..state.enemy_count] in order. Start with a simple rule: if the player is adjacent, attack; otherwise wait. Add tests that verify enemy turns run only after a valid player action.

### Combat

Replace src/systems/combat.zig with a tiny stat model: hp, attack, and defense on entities. Resolve bump attacks in movement.tryMovePlayer when the destination contains an enemy. Add log messages for hits, defeats, and blocked attacks.

### Inventory

Add src/entities/item.zig and an inventory array to State. Keep pickup/drop as systems so rendering only displays item glyphs. Use fixed-size arrays at first; switch to dynamic storage only when the rules need it.

### Field Of View

Add a visibility bitset to State and compute it after every valid player turn. Start with a simple radius check or Bresenham line-of-sight before adding shadowcasting. Render unseen tiles as dark rectangles and remembered tiles with dim colors in src/window.zig.

### Graphical Window

The current renderer already opens a native zglfw window and uses zgui for the HUD and message panel. A later pass can move tile rendering from zgui draw lists to a dedicated zgpu/WebGPU renderer while keeping the same State, systems, and world modules.
