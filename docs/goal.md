Absolutely — here’s a copy-paste agent prompt plus a practical scaffold outline for a Zig roguelike using zig-gamedev. zig-gamedev is a Zig game-development ecosystem with sample applications, and its repo documents running sample builds with zig build ...-run and listing targets with zig build -l.

Agent prompt
You are a senior Zig game developer. Scaffold a new turn-based roguelike project using the zig-gamedev ecosystem as the foundation.

Goals:

Create a buildable Zig project that runs from the command line.

Set up a minimal first playable roguelike loop: window, grid render, player movement, walls, and turn progression.

Keep the architecture simple, modular, and easy to extend.

Prefer a room-and-corridor roguelike structure with deterministic game state and clean separation of rendering and simulation.

Requirements:

Use Zig and align with zig-gamedev conventions where useful.

Make zig build and zig build run work.

Include a README.md with setup, build, run, and next-step instructions.

Create a clear source layout for game state, input handling, rendering, world generation, entities, and systems.

Add placeholder asset/config paths, but do not block on real assets.

Keep the first pass focused on code organization and a playable prototype, not polish.

Deliverables:

Project scaffold.

Build configuration.

Initial source files.

README.

Short notes on how to add enemies, combat, inventory, and FOV next.

Output code that is ready to build and easy to modify.

Suggested scaffold
text
.
├─ build.zig
├─ build.zig.zon
├─ README.md
├─ assets/
├─ src/
│ ├─ main.zig
│ ├─ app.zig
│ ├─ game.zig
│ ├─ state.zig
│ ├─ input.zig
│ ├─ render.zig
│ ├─ config.zig
│ ├─ world/
│ │ ├─ map.zig
│ │ ├─ generation.zig
│ │ └─ tile.zig
│ ├─ entities/
│ │ ├─ entity.zig
│ │ ├─ player.zig
│ │ └─ enemy.zig
│ ├─ systems/
│ │ ├─ turn.zig
│ │ ├─ movement.zig
│ │ └─ combat.zig
│ └─ ui/
│ ├─ hud.zig
│ └─ log.zig
└─ tests/
This matches the kind of sample-app organization zig-gamedev is meant to support, while leaving room for the roguelike systems you’ll add later.

First implementation order
Project setup and build.

Window creation and loop.

Grid/tile rendering.

Player movement.

Wall collision.

Turn advancement.

Dungeon generation stub.

Enemy and combat stubs.

That order gives you a working slice quickly and avoids overengineering before you have a playable core.

File-by-file tasks for the agent
build.zig
Define the executable.

Add a run step.

Keep debug iteration fast.

Wire in any zig-gamedev dependencies or local modules needed for the first playable build.

src/main.zig
Create the app entry point.

Initialize the game.

Enter the update/render loop.

Handle clean shutdown.

src/game.zig
Own the main game object.

Connect input, simulation, and rendering.

Manage the current game state and turn flow.

src/state.zig
Store player position, map, enemy list, turn count, and message log.

Keep simulation data separate from rendering data.

src/world/map.zig
Represent the dungeon grid.

Track wall/floor tiles.

Provide collision and bounds helpers.

src/world/generation.zig
Generate a tiny test dungeon first.

Later expand to room-and-corridor generation.

src/systems/movement.zig
Move the player on the grid.

Prevent walking through walls.

Trigger end-of-turn after valid actions.

src/systems/turn.zig
Resolve player and enemy turns.

Keep the logic deterministic.

src/render.zig
Draw tiles, player, enemies, and HUD placeholders.

Keep rendering separate from game rules.

src/ui/log.zig
Add a simple message log for combat and events.

README content the agent should include
Zig version requirement.

How to install/run zig-gamedev or reference it.

zig build

zig build run

Project layout.

Next milestones.

Notes on where to add assets later.

Helpful design rules
Use plain structs before introducing ECS.

Keep the first map tiny, like 40x25 or similar.

Use a tile size that makes debugging easy.

Make input turn-based, not real-time.

Add one debug overlay early, even if it’s just text.
