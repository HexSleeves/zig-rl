# Agent Handoff — zig-rl Roguelike

Date: 2026-06-06  
Plan: `docs/roguelite-campaign-plan.md`  
Stack: Zig 0.16.0, zig-gamedev (zgui/zglfw/zopengl), branch `main`  
Tests: 33 integration (tests/simulation.zig) + 96 inline = all passing (`zig build test` → exit 0)

---

## Completed Milestones (M0–M8)

| # | Name | Key additions |
|---|------|---------------|
| M0 | Architecture | comptime ID factory, fixed-cap stores, seeded RNG |
| M1 | Core loop | movement, bump-melee, turn system, message log |
| M2 | Combat | melee/ranged, factions, status effects, energy scheduler |
| M3 | FOV | recursive shadowcasting, explored/visible rendering |
| M4 | Procgen | seeded BSP rooms, 8 zone archetypes, L-corridors, F2 zone overlay |
| M5 | Items | 18 item defs, ItemStore, player HP, enemy damage, loot tables, G=pickup, I=inventory |
| M6 | Hacking | ObjectStore, door tiles (block move+sight), interact/hack actions, camera alerts, alert decay, lockdown |
| M7 | Campaign | CampaignState: RunOutcome/RunRecord, OperativeBackground, FacilityWing/WingStatus, unlock pool, glossary, lore, run history, endRun() integration |
| M8 | Save/Load | src/save/save.zig: SAVE_VERSION=1, ZRLC/ZRLR/ZRLY magic, field-by-field binary serialization, crash-safe atomic writes (.tmp→sync→rename), Rng.getState/setState, saveCampaign/loadCampaign/saveRun/loadRun/saveReplayHeader |
| M9 | UI revamp | In-screen facility-OS UI on zgui draw-lists (no gameplay imgui windows; Debug F1 kept as sole dev window). New `src/ui/`: theme (cyan-on-dark palette + alert hazard ramp + lerp/dim/withAlpha), camera (follow + tile↔screen, clamp/center), layout (region rects + window sizing + `so()` HiDPI offset scaler), draw (panel/bar/glyph/glow/scanlines/vignette + corner brackets), panels (header/vitals/loadout/inspect/log_panel/map_view), screens (main_menu/game_over/inventory), scene (composer + Anim). Follow camera, mouse hover-inspect with nearest-hostile fallback, FOV tri-state, threat-colored enemies, alert-driven frame recolor + scanlines/vignette/sync-glitch/lockdown-pulse FX, HiDPI-scaled throughout. Modes: boot→main_menu, death→game_over, `State.startRun()`. Removed `render.zig` + `ui/hud.zig`. Plan/spec: `docs/superpowers/{plans,specs}/2026-06-06-ui-revamp*.md` |

---

## Source File Map

```
src/
  config.zig           map 40×25, max_enemies=4, max_items=64, max_objects=32
  ids.zig              comptime makeId: ActorId ItemId ObjectId CellIndex DefinitionId FactionId AbilityId EffectId
                       player_actor_id = ActorId{.value=0}
  rng.zig              Rng(DefaultPrng): nextBounded/nextRange
  energy_scheduler.zig ACTION_THRESHOLD=100 BASE_SPEED=100; pub tick()
  run_state.zig        RunState: map player actors items objects scheduler rng visibility rooms[]
                       kills: u32, items_found: u32 (incremented by actions.zig)
                       isPassable() tickCameras() tickAlertDecay() raiseAlert() recomputeFov()
  game.zig             handle(): executeAction → deductCost(player) → tick() → enemy turns → player death check
                       → tickCameras → tickAlertDecay → lockdown
                       quit → state.endRun(.quit); player hp<=0 → state.endRun(.operative_death)
  actions.zig          intentFromCommand → validateIntent → executeAction
                       Actions: move wait melee_bump pickup use_item interact hack quit
  input.zig            Command: move wait quit pickup hack
  window.zig           zgui loop; keys: WASD/HJKL=move .=wait Q=quit G=pickup I=inventory H=hack
                       F1=debug F2=zone-overlay; lockdown banner in HUD
  state.zig            State{run: RunState, campaign: CampaignState, current_mode, quit_requested}
                       endRun(outcome) → builds RunRecord (score=kills*10+floor*50+items*5) → campaign.recordRunEnd()
  factions.zig         PLAYER SECURITY ROGUE_MACHINES ESCAPED_EXPERIMENTS NEUTRAL; isHostile()
  status.zig           StatusSet packed (bleeding stunned burning emped jammed_weapon shielded cloaked detected)
  visibility.zig       VisibilityMap 40×25; recursive shadowcasting compute()

  world/
    tile.zig           TileKind: wall floor door
                       wall() floor() door_closed() door_open()
                       blocksMovement(): wall=true, door=blocks_sight, floor=false
    map.zig            Map[1000]Tile; isBlockedAt isBlocked set get
    generation.zig     generateStarterDungeon() (legacy, used in tests)
    procgen.zig        generate(rng, floor_num) → GeneratedFloor
                       {map, rooms[8], spawns[16], door_positions[8], terminal_positions[8], camera_positions[8]}
                       ZoneType: habitation labs reactor security cargo medbay data_core maintenance
                       RoomFlags packed: combat loot objective hazard terminal safe ambush vault
    map_object.zig     ObjectKind: door terminal camera locker alarm generator
                       ObjectState: closed open locked hacked broken disabled
                       MapObject{id x y kind state powered difficulty alive facing}

  entities/
    entity.zig         Position{x,y: i32}
    player.zig         Player{position glyph hp=20 max_hp=20 armor=0 evasion=15 inventory}
    enemy.zig          Enemy{position glyph name alive hp max_hp armor accuracy evasion speed=100
                       faction awareness=8 ai: AiState status: StatusSet}

  stores/
    actor_store.zig    ActorStore[max_enemies]; addEnemy getEnemy getEnemyMut enemyAtPosition glyphAt
    item_store.zig     ItemStore[max_items]; ItemInstance{def_id x y owner charges condition quirks identified}
                       addItem getItem getItemMut removeItem firstItemAt
    object_store.zig   ObjectStore[max_objects]; addObject getObject getObjectMut objectAt removeObject

  items/
    item_def.zig       ItemDef ItemKind ItemQuirks ITEM_DEFS[18] getById()
    inventory.zig      Inventory[20]?ItemId count equipment; Equipment[7 slots]; EquipSlot enum
    loot_table.zig     rollLoot(zone, floor, rng) → ?u16

  systems/
    movement.zig       tryMovePlayer tryMovePlayerRun; Direction; MoveResult
    turn.zig           endActorTurn(run, actor_id) → u32 cost
                       move-into-player → attack; no enemy stacking
    combat.zig         playerMeleeAttack enemyMeleeAttack hasLineOfSight playerRangedAttack

  ai/
    behavior.zig       AiState{mode last_seen_x/y turns_since_saw}; AiMode: sentry idle patrol chase flee
    pathfind.zig       stepToward stepAway → ?Direction
    ai_system.zig      decideAction(run, enemy_id, ai_state) → AiAction{move wait melee_attack}

  ui/
    hud.zig            HUD helpers
    log.zig            MessageLog fixed-cap circular buffer

  campaign_state.zig   CampaignState: RunOutcome RunRecord OperativeBackground FacilityWing WingStatus
                       recordRunEnd() getLastRun() unlockItem/Background seeItemDef/EnemyGlyph discoverLore
                       wing_status[4] run_history[20] seen_item_defs seen_enemy_glyphs discovered_lore
                       applyUnlockProgression() — beta unlocks on extraction; ex_military on 5+ kills

  save/
    save.zig           SAVE_VERSION=1; CAMPAIGN_MAGIC="ZRLC" RUN_MAGIC="ZRLR" REPLAY_MAGIC="ZRLY"
                       CommandByte enum (none=0..hack=12) for replay log
                       saveCampaign/loadCampaign → saves/campaign.sav (~8KB)
                       saveRun/loadRun → saves/run.sav (~32KB); loadRun calls RunState.init() then overwrites
                       saveReplayHeader(seed) → saves/replay.log
                       writeAtomic(): write .tmp → sync → rename (crash-safe)
                       bitset32ToU32/u32ToBitset32; encodeTile/decodeTile; glyphToName

tests/
  simulation.zig       33 integration tests
```

---

## Turn Loop

```
player acts → executeAction → deductCost(player, costOf(action))
→ scheduler.tick() (all actors += speed energy)
→ for i in 1..scheduler.count:
    if energy >= 100 → endActorTurn(run, id) → deductCost(id, cost)
→ tickCameras()   (camera cone LoS → raiseAlert(8) if player spotted)
→ tickAlertDecay() (alert -= 1 if > 0)
→ lockdown check: if alert >= 80, lock all closed doors
```

---

## Key Patterns

- **ID factory**: `makeId("Name")` → struct with `value: u32`, `.invalid`, `.eql()`, `.isValid()`
- **Fixed stores**: no heap during gameplay; array + count + next_id
- **GateGuard hook**: before EVERY Edit/Write state: (1) all files that import target, (2) affected public functions, (3) user instruction verbatim
- **Branches**: `milestone-N-shortname`; merge `--no-ff` into main after tests pass
- **Caveman mode**: terse responses, fragments OK, no filler — active until "stop caveman" or "normal mode"

---

## Remaining Milestones

### M9: Production UI, Audio, Art Pipeline, Settings
- Better tile rendering: camera centering, hover/inspect panel, target preview, minimap, message filtering
- Full keyboard-first controls + mouse support for inspection/inventory
- Settings: tile scale, fullscreen, animation speed, text scale, colorblind palettes, keybindings
- Audio via zaudio (optional, event-driven, headless-safe)

### M10: Content Production & Balancing
- Move content defs into `assets/config/` (actors, items, abilities, status effects, room archetypes, spawn tables, campaign unlocks)
- Balance tuning pass
- Achievements/challenges

---

## Suggested Next Session Start

```
Read docs/agent-handoff.md. Implement Milestone 9: Production UI, Audio, Art Pipeline, Settings.
Key files: src/window.zig (rendering loop), src/ui/hud.zig, src/render.zig.
GateGuard active — state facts before every Edit/Write.
Caveman mode active.
```
