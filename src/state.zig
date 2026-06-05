const std = @import("std");
const config = @import("config.zig");
const generation = @import("world/generation.zig");
const map_mod = @import("world/map.zig");
const player_mod = @import("entities/player.zig");
const enemy_mod = @import("entities/enemy.zig");
const log_mod = @import("ui/log.zig");

pub const State = struct {
    allocator: std.mem.Allocator,
    map: map_mod.Map,
    player: player_mod.Player,
    enemies: [config.max_enemies]enemy_mod.Enemy,
    enemy_count: usize,
    turn_count: u64,
    log: log_mod.MessageLog,
    quit_requested: bool,

    pub fn init(allocator: std.mem.Allocator) State {
        return .{
            .allocator = allocator,
            .map = generation.generateStarterDungeon(),
            .player = .{},
            .enemies = .{
                .{ .position = .{ .x = 28, .y = 10 } },
                .{ .position = .{ .x = 32, .y = 14 }, .glyph = 's', .name = "sentinel" },
                .{ .position = .{ .x = 0, .y = 0 }, .alive = false },
                .{ .position = .{ .x = 0, .y = 0 }, .alive = false },
            },
            .enemy_count = 2,
            .turn_count = 0,
            .log = log_mod.MessageLog.init(allocator),
            .quit_requested = false,
        };
    }

    pub fn deinit(self: *State) void {
        self.log.deinit();
    }

    pub fn enemyGlyphAt(self: *const State, x: i32, y: i32) ?u8 {
        var i: usize = 0;
        while (i < self.enemy_count) : (i += 1) {
            const enemy = self.enemies[i];
            if (enemy.alive and enemy.position.x == x and enemy.position.y == y) {
                return enemy.glyph;
            }
        }
        return null;
    }
};
