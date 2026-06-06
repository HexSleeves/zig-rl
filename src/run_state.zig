const std = @import("std");
const config = @import("config.zig");
const procgen = @import("world/procgen.zig");
const map_mod = @import("world/map.zig");
const player_mod = @import("entities/player.zig");
const enemy_mod = @import("entities/enemy.zig");
const log_mod = @import("ui/log.zig");
const actor_store = @import("stores/actor_store.zig");
const item_store = @import("stores/item_store.zig");
const energy_scheduler = @import("energy_scheduler.zig");
const rng_mod = @import("rng.zig");
const factions = @import("factions.zig");
const visibility_mod = @import("visibility.zig");

/// RunState holds all data for a single dungeon run.
pub const RunState = struct {
    map: map_mod.Map,
    player: player_mod.Player,
    actors: actor_store.ActorStore,
    items: item_store.ItemStore,
    turn_count: u64,
    log: log_mod.MessageLog,
    current_floor: u32,
    run_seed: u64,
    scheduler: energy_scheduler.EnergyScheduler,
    rng: rng_mod.Rng,
    visibility: visibility_mod.VisibilityMap,
    alert_level: u8 = 0,
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

        var vis = visibility_mod.VisibilityMap.init();
        vis.compute(&floor.map, player_x, player_y, FOV_RADIUS);

        return RunState{
            .map = floor.map,
            .player = .{ .position = .{ .x = player_x, .y = player_y } },
            .actors = actors,
            .items = item_store.ItemStore.init(),
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

    /// Get the glyph of a living enemy at (x, y), or null if none.
    pub fn enemyGlyphAt(self: *const RunState, x: i32, y: i32) ?u8 {
        return self.actors.glyphAt(x, y);
    }
};
