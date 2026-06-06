const std = @import("std");
const config = @import("config.zig");
const procgen = @import("world/procgen.zig");
const map_mod = @import("world/map.zig");
const tile_mod = @import("world/tile.zig");
const player_mod = @import("entities/player.zig");
const enemy_mod = @import("entities/enemy.zig");
const log_mod = @import("ui/log.zig");
const actor_store = @import("stores/actor_store.zig");
const item_store = @import("stores/item_store.zig");
const object_store = @import("stores/object_store.zig");
const map_object = @import("world/map_object.zig");
const loot_table = @import("items/loot_table.zig");
const energy_scheduler = @import("energy_scheduler.zig");
const rng_mod = @import("rng.zig");
const factions = @import("factions.zig");
const visibility_mod = @import("visibility.zig");
const combat_mod = @import("systems/combat.zig");

/// RunState holds all data for a single dungeon run.
pub const RunState = struct {
    map: map_mod.Map,
    player: player_mod.Player,
    actors: actor_store.ActorStore,
    items: item_store.ItemStore,
    objects: object_store.ObjectStore,
    turn_count: u64,
    log: log_mod.MessageLog,
    current_floor: u32,
    run_seed: u64,
    scheduler: energy_scheduler.EnergyScheduler,
    rng: rng_mod.Rng,
    visibility: visibility_mod.VisibilityMap,
    alert_level: u8 = 0,
    kills: u32 = 0,
    items_found: u32 = 0,
    rooms: [procgen.max_rooms]procgen.Room,
    room_count: usize,

    pub const FOV_RADIUS: u32 = 8;

    pub fn init(allocator: std.mem.Allocator) !RunState {
        var actors = actor_store.ActorStore.init();
        var scheduler = energy_scheduler.EnergyScheduler.init();
        const seed: u64 = 12345;
        var rng = rng_mod.Rng.init(seed);

        const floor = procgen.generate(&rng, 1);

        // Place player at spawn point
        var player_x: i32 = config.player_start_x;
        var player_y: i32 = config.player_start_y;
        for (floor.spawns[0..floor.spawn_count]) |sp| {
            if (sp.kind == .player) {
                player_x = sp.x;
                player_y = sp.y;
                break;
            }
        }

        // Place enemies at enemy spawn points
        const enemy_defs = [_]struct { glyph: u8, name: []const u8, hp: i32, armor: u32, accuracy: u32, speed: u32 }{
            .{ .glyph = 'g', .name = "guard", .hp = 10, .armor = 0, .accuracy = 70, .speed = 100 },
            .{ .glyph = 's', .name = "sentinel", .hp = 15, .armor = 2, .accuracy = 75, .speed = 80 },
            .{ .glyph = 'r', .name = "rogue", .hp = 8, .armor = 0, .accuracy = 65, .speed = 110 },
            .{ .glyph = 'e', .name = "enforcer", .hp = 20, .armor = 3, .accuracy = 80, .speed = 70 },
        };
        var def_idx: usize = 0;
        for (floor.spawns[0..floor.spawn_count]) |sp| {
            if (sp.kind != .enemy) continue;
            if (def_idx >= enemy_defs.len) break;
            const def = enemy_defs[def_idx];
            def_idx += 1;
            if (actors.addEnemy(.{
                .position = .{ .x = sp.x, .y = sp.y },
                .glyph = def.glyph,
                .name = def.name,
                .hp = def.hp,
                .max_hp = def.hp,
                .accuracy = def.accuracy,
                .armor = def.armor,
                .speed = def.speed,
                .faction = factions.SECURITY,
            })) |id| {
                scheduler.addActor(id, def.speed);
            }
        }

        // Spawn loot items in rooms (skip room 0 — player spawn)
        var items = item_store.ItemStore.init();
        for (floor.rooms[0..floor.room_count], 0..) |room, room_idx| {
            if (room_idx == 0) continue; // skip player start room
            if (loot_table.rollLoot(room.zone, 1, &rng)) |def_id| {
                const lx: i32 = @intCast(room.centerX());
                const ly: i32 = @intCast(room.centerY());
                _ = items.addItem(def_id, lx, ly);
            }
        }

        // Place map objects from procgen
        var objects = object_store.ObjectStore.init();

        // Copy map so we can mutate it
        var run_map = floor.map;

        // Doors at corridor elbows
        for (floor.door_positions[0..floor.door_count]) |dp| {
            const t = run_map.get(dp.x, dp.y);
            if (t.kind == .floor) {
                run_map.set(dp.x, dp.y, tile_mod.Tile.door_closed());
                _ = objects.addObject(@intCast(dp.x), @intCast(dp.y), .door, .closed, 3);
            }
        }

        // Terminals
        for (floor.terminal_positions[0..floor.terminal_count]) |tp| {
            _ = objects.addObject(@intCast(tp.x), @intCast(tp.y), .terminal, .closed, 5);
        }

        // Cameras
        for (floor.camera_positions[0..floor.camera_count]) |cp| {
            if (objects.addObject(@intCast(cp.x), @intCast(cp.y), .camera, .closed, 4)) |cam_id| {
                if (objects.getObjectMut(cam_id)) |cam| {
                    cam.facing = cp.facing;
                }
            }
        }

        var vis = visibility_mod.VisibilityMap.init();
        vis.compute(&run_map, player_x, player_y, FOV_RADIUS);


        return RunState{
            .map = run_map,
            .player = .{ .position = .{ .x = player_x, .y = player_y } },
            .actors = actors,
            .items = items,
            .objects = objects,
            .turn_count = 0,
            .log = log_mod.MessageLog.init(allocator),
            .current_floor = 1,
            .run_seed = seed,
            .scheduler = scheduler,
            .rng = rng,
            .visibility = vis,
            .rooms = floor.rooms,
            .room_count = floor.room_count,
        };
    }

    pub fn deinit(self: *RunState) void {
        self.log.deinit();
    }

    pub fn recomputeFov(self: *RunState) void {
        self.visibility.compute(&self.map, self.player.position.x, self.player.position.y, FOV_RADIUS);
    }

    pub fn raiseAlert(self: *RunState, amount: u8) void {
        self.alert_level = @min(100, self.alert_level + amount);
    }

    pub fn isPassable(self: *const RunState, x: i32, y: i32) bool {
        return !self.map.isBlockedAt(x, y);
    }

    /// Tick cameras: powered cameras raise alert if player is in their cone.
    pub fn tickCameras(self: *RunState) void {
        const px = self.player.position.x;
        const py = self.player.position.y;
        var i: usize = 0;
        while (i < self.objects.count) : (i += 1) {
            const obj = &self.objects.objects[i];
            if (!obj.alive or obj.kind != .camera or !obj.powered) continue;
            if (obj.state == .disabled) continue;
            // facing: 0=N(dy-1),2=E(dx+1),4=S(dy+1),6=W(dx-1)
            const facing = obj.facing;
            var dist: i32 = 1;
            while (dist <= 5) : (dist += 1) {
                // Check center and ±1 perpendicular tile at each distance
                var perp: i32 = -1;
                while (perp <= 1) : (perp += 1) {
                    const cx = obj.x + switch (facing) {
                        0 => perp,
                        1 => dist,
                        2 => dist,
                        3 => dist,
                        4 => perp,
                        5 => -dist,
                        6 => -dist,
                        7 => -dist,
                        else => @as(i32, 0),
                    };
                    const cy = obj.y + switch (facing) {
                        0 => -dist,
                        1 => -dist,
                        2 => perp,
                        3 => dist,
                        4 => dist,
                        5 => dist,
                        6 => perp,
                        7 => -dist,
                        else => @as(i32, 0),
                    };
                    if (cx == px and cy == py) {
                        if (combat_mod.hasLineOfSight(&self.map, obj.x, obj.y, px, py)) {
                            self.raiseAlert(8);
                            return;
                        }
                    }
                }
            }
        }
    }

    pub fn tickAlertDecay(self: *RunState) void {
        if (self.alert_level > 0) {
            self.alert_level -= 1;
        }
    }

    /// Get the glyph of a living enemy at (x, y), or null if none.
    pub fn enemyGlyphAt(self: *const RunState, x: i32, y: i32) ?u8 {
        return self.actors.glyphAt(x, y);
    }
};
