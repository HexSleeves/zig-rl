const std = @import("std");
const config = @import("config.zig");
const generation = @import("world/generation.zig");
const map_mod = @import("world/map.zig");
const player_mod = @import("entities/player.zig");
const enemy_mod = @import("entities/enemy.zig");
const log_mod = @import("ui/log.zig");
const actor_store = @import("stores/actor_store.zig");
const item_store = @import("stores/item_store.zig");

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

    pub fn init(allocator: std.mem.Allocator) !RunState {
        var actors = actor_store.ActorStore.init();
        // Add 2 placeholder enemies matching previous state.zig positions
        _ = actors.addEnemy(.{ .position = .{ .x = 28, .y = 10 } });
        _ = actors.addEnemy(.{ .position = .{ .x = 32, .y = 14 }, .glyph = 's', .name = "sentinel" });

        return RunState{
            .map = generation.generateStarterDungeon(),
            .player = .{},
            .actors = actors,
            .items = item_store.ItemStore.init(),
            .turn_count = 0,
            .log = log_mod.MessageLog.init(allocator),
            .current_floor = 1,
            .run_seed = 0,
        };
    }

    pub fn deinit(self: *RunState) void {
        self.log.deinit();
    }

    /// Get the glyph of a living enemy at (x, y), or null if none.
    pub fn enemyGlyphAt(self: *const RunState, x: i32, y: i32) ?u8 {
        return self.actors.glyphAt(x, y);
    }
};
