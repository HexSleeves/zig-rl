# Agent Handoff — zig-rl Roguelike

## Project

Sci-fi roguelite in Zig 0.16.0 using zig-gamedev (zgui/zglfw/zopengl). Plan: `docs/roguelite-campaign-plan.md`.

## Current State

Branch: `main`. All tests pass (`zig build test`). Milestones 0–5 complete and merged.

## Completed Milestones

- **M0** Stable architecture (comptime ID factory, fixed-cap stores, seeded RNG)
- **M1** Core gameplay loop (movement, bump-melee, turn system, message log)
- **M2** Combat (melee/ranged, factions, status effects, energy scheduler)
- **M3** FOV (recursive shadowcasting, explored/visible rendering, stealth)
- **M4** Procedural generation (seeded BSP room placer, 8 zone archetypes, L-corridor connector, spawn points, F2 debug zone overlay)
- **M5** Items/Inventory/Equipment/Loot (18 item defs, ItemStore, player HP, enemy damage, loot tables, G=pickup, I=inventory panel)

## Key Architecture

### Files

```
src/
  config.zig           — map 40x25, max_enemies=4, max_items=64
  ids.zig              — comptime makeId factory: ActorId, ItemId, CellIndex, etc.
  rng.zig              — Rng wraps DefaultPrng; nextBounded/nextRange
  energy_scheduler.zig — ACTION_THRESHOLD=100, BASE_SPEED=100; pub tick()
  run_state.zig        — RunState: map, player, actors, items, scheduler, rng, visibility, rooms[]
  game.zig             — Game.handle(): execute player action → tick scheduler → run enemy turns
  actions.zig          — intentFromCommand → validateIntent → executeAction (move/wait/melee_bump/pickup/use_item)
  input.zig            — Command enum (move/wait/quit/pickup)
  window.zig           — zgui render loop; F1=debug, F2=zone overlay, I=inventory, G=pickup
  state.zig            — State wraps RunState + current_mode + quit_requested
  factions.zig         — PLAYER/SECURITY/ROGUE_MACHINES/ESCAPED_EXPERIMENTS/NEUTRAL
  status.zig           — StatusSet (bleeding/stunned/burning/emped/jammed_weapon/shielded/cloaked/detected)
  visibility.zig       — VisibilityMap 40x25; recursive shadowcasting compute()

  world/
    tile.zig           — Tile {kind, blocks_sight}; wall()/floor()
    map.zig            — Map [1000]Tile; isBlockedAt/isBlocked/set/get
    generation.zig     — generateStarterDungeon() (legacy, still used in some tests)
    procgen.zig        — generate(rng, floor_num) → GeneratedFloor {map, rooms[8], spawns[16]}
                         ZoneType enum, RoomFlags packed struct, Room struct

  entities/
    entity.zig         — Position {x,y: i32}
    player.zig         — Player {position, glyph, hp=20, max_hp=20, armor=0, evasion=15, inventory}
    enemy.zig          — Enemy {position, glyph, name, alive, hp, max_hp, armor, accuracy, evasion,
                         speed, faction, awareness=8, ai: AiState, status: StatusSet}

  stores/
    actor_store.zig    — ActorStore [max_enemies]Enemy; addEnemy/getEnemy/getEnemyMut/enemyAtPosition/glyphAt
    item_store.zig     — ItemStore [max_items]ItemInstance; addItem/getItem/getItemMut/removeItem/firstItemAt

  items/
    item_def.zig       — ItemDef, ItemKind, ItemQuirks, ITEM_DEFS[18], getById()
    inventory.zig      — Inventory [20]?ItemId, Equipment [7 slots], EquipSlot enum
    loot_table.zig     — rollLoot(zone, floor, rng) → ?u16 (60% spawn, zone-weighted pools)

  systems/
    movement.zig       — tryMovePlayer/tryMovePlayerRun; Direction; MoveResult
    turn.zig           — endActorTurn(run, actor_id) — AI decision + move/melee/wait exec + combat logging
    combat.zig         — playerMeleeAttack/enemyMeleeAttack/hasLineOfSight/playerRangedAttack

  ai/
    behavior.zig       — AiState {mode, last_seen_x/y, turns_since_saw}; AiMode enum
    pathfind.zig       — stepToward/stepAway(map, fx,fy, tx,ty) → ?Direction
    ai_system.zig      — decideAction(run, enemy_id, ai_state) → AiAction {move/wait/melee_attack}
                         Modes: sentry/idle/patrol/chase/flee; awareness=8, hasLineOfSight check

  ui/
    hud.zig            — HUD helpers
    log.zig            — MessageLog fixed-cap circular buffer

tests/
  simulation.zig       — integration tests (~31 passing)
```

### Turn Loop (game.zig)

```
player acts → executeAction → deductCost(player, cost)
→ scheduler.tick() (all actors gain speed energy)
→ iterate slots[1..count]: if energy >= 100 → endActorTurn → deductCost
```

### Enemy AI Flow

Chase mode: stepToward → if target==player tile → enemyMeleeAttack (turn.zig intercept)
Enemies don't stack on same tile. Dead enemies removed from scheduler via removeActor().

## Next Milestone: M6 — Hacking, Facility Systems, Sci-Fi Quirks

From `docs/roguelite-campaign-plan.md`:

- Interactable map objects: doors, terminals, cameras, turrets, elevators, generators, vents, lockers, cryopods, alarms
- Hacking actions (turn-consuming, risk/reward): unlock doors, disable cameras, reroute power, reveal map, turn turrets, lower alert, trigger traps on failure
- Facility simulation: alert level (already exists as `run_state.alert_level u8`), power zones, camera coverage, lockdown states, environmental hazards
- Memorable quirks: reactor leak, AI voice lies, doors fail after EMP, oxygen/heat zones, prototype gear side effects

### Suggested M6 Approach

1. Add ObjectKind enum + MapObject struct (position, kind, state: open/closed/hacked/broken, powered: bool)
2. Add ObjectStore [max_objects]MapObject to RunState
3. Procgen: place doors at corridor-room junctions, terminals in terminal rooms, cameras in security rooms
4. Map blocking: closed doors block movement + LoS; open doors do not
5. Hacking: H key → hack adjacent object; cost=150 energy; success based on rng vs difficulty
6. Camera: patrol arc; if player in arc + LoS → raise alert
7. Alert decay: tickAlert() each player turn (slow decay when undetected)
8. Power zones: generator room powers adjacent rooms; EMP cuts power
9. Lockdown: alert >= 80 locks all doors; terminal hack cancels

## Session Conventions

- **CAVEMAN MODE ACTIVE** — terse responses, fragments OK, no filler
- GateGuard hook requires facts before any file edit: list all importers, affected functions, user instruction verbatim
- Branches: `milestone-N-shortname`; merge --no-ff into main after tests pass
- Comptime ID factory for all typed IDs (see ids.zig makeId pattern)
- Fixed-capacity arrays only — no heap during gameplay
- Enemy/item IDs start at 1 (player = ActorId{.value=0})
- All tests must pass before merge

## Test Count

~31 tests passing. Key test locations:
onses, fragments OK, no filler

- GateGuard hook requires facts before any file edit: list all importers, affected functions, user instruction verbatim
- Branches: `milestone-N-shortname`; merge --no-ff into main after tests pass
- Comptime ID factory for all typed IDs (see ids.zig makeId pattern)
- Fixed-capacity arrays only — no heap during gameplay
- Enemy/item IDs start at 1 (player = ActorId{.value=0})
- All tests must pass before merge

## Test Count

~31 tests passing. Key test locations:

- tests/simulation.zig (integration)
- Inline in: energy_scheduler, rng, visibility, procgen, item_def, inventory, item_store, loot_table, combat, actions
