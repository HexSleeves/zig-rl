# Sci-Fi Roguelite Campaign Plan For zig-rl

## Summary

Build zig-rl from the current clean prototype into a production roguelite hybrid: a single-operative sci-fi facility crawler with procedural runs, energy-based turns, tactical combat, FOV/exploration, items/equipment, hacking, persistent unlock pools, campaign progression, save/load, and production-grade debug/test tooling.

Current audit: the repo already has a healthy deterministic core: fixed starter map, player movement, wall collision, turn count, bounded message log, enemy placeholders, zglfw/zopengl/zgui native rendering, and simulation tests. The plan should extend that architecture rather than replace it: keep simulation deterministic and testable, keep rendering isolated, and make content data-driven before adding large amounts of campaign content.

Research basis: established roguelike build sequences typically add dungeon generation, FOV, enemies, damage, UI, inventory, targeting, save/load, deeper floors, difficulty, and gear after the first movement/map slice; this aligns well with the current repo state. For this project's selected sci-fi roguelite direction, use traditional roguelike fundamentals as the run engine, then add meta-progression and campaign structure on top.

## Key Design Decisions

- **Game identity:** sci-fi facility roguelite, not classic fantasy dungeon.
- **Player model:** single operative by default, not squad-based, to preserve roguelike readability and keep v1 implementation tractable.
- **Run structure:** procedural multi-zone facility runs with sector objectives, extraction/failure states, and persistent unlocks.
- **Meta-progression:** unlock pool progression by default: new gear, operative starts, implants, facility intel, and lore enter future run pools without permanent stat inflation.
- **Turn model:** energy-based actor turns. RogueBasin describes energy systems as tick-based loops where actors gain energy and actions deduct costs; this supports variable action costs for hacking, reloads, heavy weapons, implants, and fast/slow enemies. Cogmind's turn-time design notes also call out that greater time granularity helps larger roguelikes support broader content, while requiring good UI feedback to avoid opacity.
- **Generation model:** start with room/corridor sectors, then evolve to facility zones with loops, connectors, locked branches, vaults, hazards, and objective rooms. Bob Nystrom's generator goals are a good fit: connected dungeons, loops, open rooms, passageways, and tunable knobs for different area feel.
- **Rendering/UI:** keep current zglfw/zopengl/zgui backend for v1. zig-gamedev is a modular toolbox, and zgui provides Dear ImGui bindings, draw-list rendering, and a test engine API, so it is suitable for debug overlays, inventory screens, targeting panels, and development tools before investing in a custom renderer.

## Implementation Roadmap

### Milestone 0: Stabilize The Core Architecture

- Split current monolithic State growth into stable modules: World, ActorStore, ItemStore, RunState, CampaignState, and MessageLog.
- Introduce typed IDs for actors, items, map cells, factions, abilities, effects, and content definitions.
- Keep fixed-capacity arrays for v1 where practical, but hide them behind store APIs so later dynamic storage does not rewrite systems.
- Add a deterministic RNG wrapper with explicit seed ownership: campaign seed, run seed, floor seed, and replay/test seed.
- Add a GameMode enum: main_menu, running, inventory, targeting, game_over, campaign_summary, debug.
- Add a developer diagnostics panel in zgui: seed, floor, actor count, visible tiles, current actor, action queue/energy state, FPS, and last commands.

### Milestone 1: Real Turn And Action System

- Replace turn.endPlayerTurn with an action-resolution pipeline:
  - input command becomes ActionIntent
  - intent validates against state
  - valid intent becomes Action
  - action mutates simulation
  - action consumes energy/time
  - scheduler advances actors until player input is needed again
- Add EnergyScheduler with actor energy, speed, action cost, and deterministic actor ordering.
- Use a simple energy model first:
  - move: 100 energy
  - wait: 100
  - melee: 100
  - shoot: 120
  - reload: 150
  - hack: 150
  - heavy action: 200
- Add interruptible delayed actions later through the same system: hacking terminals, charging weapons, opening sealed doors, using medkits.
- Surface turn feedback in UI: enemy moving, reload 1 turn, hack interrupted, turret recharging.

### Milestone 2: Combat, Actors, And AI

- Replace placeholder Enemy with shared actor stats:
  - hp/max_hp, armor, accuracy, evasion, speed, faction, awareness, status flags, inventory/equipment references.
- Implement bump melee, ranged line-of-fire, armor mitigation, critical hits, death/removal, and message log events.
- Add AI behaviors in layers:
  - idle/patrol
  - investigate noise
  - chase visible player
  - flee when low HP
  - use cover/doors where simple
  - turret/sentry stationary behavior
- Add factions: player, security, rogue machines, escaped experiments, neutral systems.
- Add status effects: bleeding, stunned, burning, EMP'd, jammed weapon, shielded, cloaked, detected.
- Keep AI deterministic and testable: no renderer calls, no wall-clock time, no hidden randomness outside the seeded RNG.

### Milestone 3: FOV, Stealth, And Information

- Add tile visibility fields: visible, explored, blocks_sight, and optional lit.
- Compute FOV only when relevant state changes: player movement, door state, light state, sensors, smoke, or scan effects.
- Start with symmetric shadowcasting or Bresenham/radius FOV; choose one implementation and freeze it behind visibility.compute.
- Hide enemies/items outside FOV unless detected by sensors.
- Add sci-fi information mechanics:
  - motion pings
  - camera coverage
  - terminal map reveal
  - sensor implant
  - darkness/blackout zones
  - security alert level.

### Milestone 4: Procedural Facility Generation

- Replace generateStarterDungeon with seeded generators:
  - sector graph generator
  - room placer
  - corridor/connector builder
  - door/lock/hazard placer
  - entity/item/objective spawner
- Guarantee every generated sector is solvable:
  - player spawn connected to objective
  - objective connected to exit
  - locked doors have keys, terminals, bypasses, or alternate routes
  - no critical item spawns behind its own lock
- Add zone archetypes:
  - habitation
  - labs
  - reactor
  - security
  - cargo
  - medbay
  - data core
  - maintenance tunnels
- Add room tags and spawn rules: combat, loot, objective, hazard, terminal, safe, ambush, vault.
- Add generation tests for connectivity, reachability, lock/key logic, spawn validity, and deterministic seed reproduction.
- Add a debug map inspector that can show regions, connectors, doors, FOV, and spawn tables.

### Milestone 5: Items, Inventory, Equipment, And Loot

- Add item definitions and instances:
  - weapons, ammo, armor, implants, tools, consumables, keycards, quest data, crafting parts.
- Add equipment slots:
  - primary weapon
  - sidearm/tool
  - armor rig
  - implant slots
  - utility slots
- Add inventory actions:
  - pickup/drop
  - equip/unequip
  - reload
  - consume/use
  - inspect
  - throw/place
- Add loot tables by zone, floor depth, security level, and unlock pool.
- Add item identification/quirks:
  - unstable prototype
  - illegal firmware
  - cursed equivalent as compromised
  - battery drain
  - noisy
  - EMP-sensitive
- Keep inventory UI in zgui first: item list, compare panel, stats diff, action buttons, and keyboard shortcuts.

### Milestone 6: Hacking, Facility Systems, And Sci-Fi Quirks

- Add interactable map objects:
  - doors
  - terminals
  - cameras
  - turrets
  - elevators
  - generators
  - vents
  - lockers
  - cryopods
  - alarms
- Add hacking as turn-consuming actions with risk/reward:
  - unlock doors
  - disable cameras
  - reroute power
  - reveal map
  - turn turrets
  - lower alert level
  - trigger traps on failure
- Add facility simulation:
  - alert level
  - power zones
  - camera coverage
  - lockdown states
  - environmental hazards
- Add quirks that make runs memorable:
  - reactor leak changes paths over time
  - AI voice lies about safe rooms
  - doors fail open or shut after EMP
  - oxygen/heat zones force route decisions
  - prototype gear offers powerful effects with side effects.

### Milestone 7: Campaign And Roguelite Meta-Progression

- Add persistent CampaignState separate from RunState.
- Track:
  - unlocked item definitions
  - unlocked operative backgrounds
  - discovered lore/intel
  - completed sector objectives
  - failed/succeeded runs
  - best depth/score
  - seen enemy/item glossary
- Unlock pool rules:
  - unlocks expand possible run content
  - no permanent raw HP/damage upgrades by default
  - player knowledge and content variety are the main progression
- Add campaign map:
  - multiple facility wings
  - branching run choices
  - escalating security
  - boss/objective gates
- Add endings:
  - extraction success
  - facility shutdown
  - AI assimilation
  - reactor meltdown
  - blacksite exposure.

### Milestone 8: Save/Load, Serialization, And Replays

- Add versioned save format:
  - campaign save
  - active run save
  - config/preferences
- Use explicit schema structs and SAVE_VERSION.
- Save seeds and enough state for deterministic continuation.
- Add migration tests for future save versions.
- Add replay/debug logs:
  - initial seed
  - command stream
  - major RNG draws or deterministic validation checksum
- Add crash-safe save writes: write temp file, flush, rename.

### Milestone 9: Production UI, Audio, Art Pipeline, And Settings

- Keep zgui for complex panels, but improve game presentation:
  - larger readable tiles
  - camera centering/follow
  - hover/inspect panel
  - target preview
  - minimap
  - message filtering
  - context-sensitive command hints
- Add keyboard-first controls:
  - movement
  - wait
  - inventory
  - interact
  - fire/target
  - reload
  - ability hotkeys
  - examine/look
- Add mouse support for inspection, inventory, and optional movement/targeting.
- Add settings:
  - tile scale
  - fullscreen/window scale
  - animation speed
  - text scale
  - colorblind palettes
  - keybindings.
- Add audio later via zaudio if desired; make audio event-driven and optional so tests/headless runs stay stable.

### Milestone 10: Content Production And Balancing

- Move content definitions into assets/config:
  - actors
  - items
  - abilities
  - status effects
  - room archetypes
  - spawn tables
  - campaign unlocks
- Use a simple format first, preferably Zig-loaded JSON or a small custom data table only if JSON becomes limiting.
- Add validation command or build step:
  - all referenced IDs exist
  - spawn tables are non-empty
  - item unlocks point to definitions
  - actor stats are in allowed ranges
  - campaign objectives are reachable.
- Add balancing tools:
  - simulate 1,000 generated floors
  - report unreachable maps
  - average enemy density
  - loot distribution
  - objective distance
  - alert escalation curve.

## Public Interfaces And Types To Add

- RunState: active run-only data: world, actors, items, scheduler, run seed, current floor/sector, objective state.
- CampaignState: persistent unlocks, stats, completed objectives, lore, glossary.
- ActionIntent and Action: command-level input separated from validated simulation mutations.
- EnergyScheduler: deterministic actor scheduling based on speed and action cost.
- ActorId, ItemId, CellIndex, DefinitionId: typed IDs instead of raw indices crossing module boundaries.
- ContentDb: loaded definitions for actors, items, abilities, rooms, spawns, and unlocks.
- VisibilityMap: visible/explored state and FOV recompute flags.
- SaveGame: versioned serialization root with migration path.
- DebugSnapshot: read-only state summary for zgui debug panels and test diagnostics.

## Test Plan

- Keep zig build test, zig build, and zig build run -- --smoke-test as the minimum verification gate.
- Add deterministic unit tests for:
  - action validation and energy costs
  - actor turn order and speed differences
  - combat damage/death/status effects
  - FOV visibility/explored behavior
  - pathfinding and AI target choice
  - inventory capacity/equip/use/drop
  - content definition validation
  - save/load round trip and version migration.
- Add property-style generation tests:
  - all generated maps are connected enough for objectives
  - spawn locations are walkable
  - locked content has valid access paths
  - exits and objectives are reachable
  - generation is reproducible by seed.
- Add smoke/integration scenarios:
  - start run, move, fight, pick up item, use terminal, descend/extract
  - die and return to campaign summary
  - unlock an item and see it enter future spawn pools
  - save active run, reload, continue deterministically.
- Add visual/manual checks after renderer/UI changes:
  - native window scale on high-DPI displays
  - inventory readable at default size
  - FOV colors distinguish visible/explored/unseen
  - targeting preview lines up with tiles
  - debug overlay does not obscure core play.

## Assumptions And Defaults

- The selected product direction is **roguelite hybrid + large campaign + sci-fi facility**.
- The unanswered second decision set defaults to **single operative**, **unlock-pool meta-progression**, and **energy turns**.
- The current zglfw/zopengl/zgui renderer remains for v1; move to zgpu only after core game systems are fun and stable.
- The project remains deterministic-first: all simulation systems must be testable without a window.
- The first production target is not all content complete; it is a polished vertical campaign slice with the full architecture: one facility wing, several sector archetypes, real combat, FOV, inventory, hacking, save/load, and meta unlocks.

## Research Sources

- RogueBasin, Time Systems: https://www.roguebasin.com/index.php/Time_Systems
- RogueBasin, A simple turn scheduling system -- Python implementation: https://www.roguebasin.com/index.php/A_simple_turn_scheduling_system_--_Python_implementation
- Grid Sage Games, Turn Time Systems: https://www.gridsagegames.com/blog/2019/04/turn-time-systems/
- Roguelike Tutorials, TCOD Tutorial (2019): https://rogueliketutorials.com/tutorials/tcod/2019/
- Roguelike Tutorials, Part 4 - Field of View: https://rogueliketutorials.com/tutorials/tcod/2019/part-4/
- Bob Nystrom, Rooms and Mazes: A Procedural Dungeon Generator: https://journal.stuffwithstuff.com/2014/12/21/rooms-and-mazes/
- zig-gamedev profile README: https://raw.githubusercontent.com/zig-gamedev/.github/main/profile/README.md
- zig-gamedev zgui README: https://raw.githubusercontent.com/zig-gamedev/zgui/main/README.md
