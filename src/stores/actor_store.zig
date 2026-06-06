const std = @import("std");
const ids = @import("../ids.zig");
const enemy_mod = @import("../entities/enemy.zig");
const config = @import("../config.zig");

/// Fixed-capacity store for actors. Wraps arrays behind an API.
/// Player is always at index 0 (ActorId{.value=0}).
/// Enemies occupy indices 1..max_enemies (stored at enemies[0..enemy_count]).
pub const ActorStore = struct {
    enemies: [config.max_enemies]enemy_mod.Enemy,
    enemy_count: usize,

    /// Create an empty ActorStore with no enemies.
    pub fn init() ActorStore {
        return ActorStore{
            .enemies = std.mem.zeroes([config.max_enemies]enemy_mod.Enemy),
            .enemy_count = 0,
        };
    }

    /// Get enemy by ActorId. Returns null if id is invalid or out of range.
    /// Enemy ActorIds start at 1; index into enemies array is id.value - 1.
    /// Returned pointer valid only while ActorStore is not mutated
    pub fn getEnemy(self: *const ActorStore, id: ids.ActorId) ?*const enemy_mod.Enemy {
        if (id.value == 0 or !id.isValid()) return null;
        const idx = id.value - 1;
        if (idx >= self.enemy_count) return null;
        return &self.enemies[idx];
    }

    /// Get mutable enemy by ActorId.
    /// Returned pointer valid only while ActorStore is not mutated
    pub fn getEnemyMut(self: *ActorStore, id: ids.ActorId) ?*enemy_mod.Enemy {
        if (id.value == 0 or !id.isValid()) return null;
        const idx = id.value - 1;
        if (idx >= self.enemy_count) return null;
        return &self.enemies[idx];
    }

    /// Add an enemy, returns its ActorId. Returns null if at capacity.
    /// Enemy IDs start at 1 (0 = player).
    pub fn addEnemy(self: *ActorStore, enemy: enemy_mod.Enemy) ?ids.ActorId {
        if (self.enemy_count >= config.max_enemies) return null;
        const idx = self.enemy_count;
        self.enemies[idx] = enemy;
        self.enemy_count += 1;
        // ID = index + 1 (since 0 is reserved for player)
        return ids.ActorId{ .value = @intCast(idx + 1) };
    }

    /// Number of enemies currently stored.
    pub fn enemyCount(self: *const ActorStore) usize {
        return self.enemy_count;
    }

    /// Returns a slice of enemies 0..enemy_count.
    pub fn enemiesSlice(self: *const ActorStore) []const enemy_mod.Enemy {
        return self.enemies[0..self.enemy_count];
    }

    /// Get glyph at a map position from enemies (returns null if no alive enemy there).
    pub fn glyphAt(self: *const ActorStore, x: i32, y: i32) ?u8 {
        for (self.enemies[0..self.enemy_count]) |enemy| {
            if (enemy.alive and enemy.position.x == x and enemy.position.y == y) {
                return enemy.glyph;
            }
        }
        return null;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "ActorStore init creates empty store" {
    const store = ActorStore.init();
    try std.testing.expectEqual(@as(usize, 0), store.enemyCount());
}

test "ActorStore addEnemy returns ActorId with value >= 1" {
    var store = ActorStore.init();
    const enemy = enemy_mod.Enemy{
        .position = .{ .x = 5, .y = 5 },
    };
    const maybe_id = store.addEnemy(enemy);
    try std.testing.expect(maybe_id != null);
    const id = maybe_id.?;
    try std.testing.expect(id.value >= 1);
}

test "ActorStore getEnemy returns the added enemy" {
    var store = ActorStore.init();
    const enemy = enemy_mod.Enemy{
        .position = .{ .x = 10, .y = 7 },
        .glyph = 't',
        .name = "troll",
        .alive = true,
    };
    const id = store.addEnemy(enemy).?;
    const retrieved = store.getEnemy(id);
    try std.testing.expect(retrieved != null);
    try std.testing.expectEqual(@as(i32, 10), retrieved.?.position.x);
    try std.testing.expectEqual(@as(i32, 7), retrieved.?.position.y);
    try std.testing.expectEqual(@as(u8, 't'), retrieved.?.glyph);
}

test "ActorStore glyphAt returns correct glyph for enemy position" {
    var store = ActorStore.init();
    const enemy = enemy_mod.Enemy{
        .position = .{ .x = 3, .y = 4 },
        .glyph = 'g',
        .alive = true,
    };
    _ = store.addEnemy(enemy);
    const glyph = store.glyphAt(3, 4);
    try std.testing.expect(glyph != null);
    try std.testing.expectEqual(@as(u8, 'g'), glyph.?);
}

test "ActorStore glyphAt returns null for empty position" {
    var store = ActorStore.init();
    const enemy = enemy_mod.Enemy{
        .position = .{ .x = 3, .y = 4 },
        .glyph = 'g',
        .alive = true,
    };
    _ = store.addEnemy(enemy);
    const glyph = store.glyphAt(99, 99);
    try std.testing.expect(glyph == null);
}

test "ActorStore at capacity addEnemy returns null" {
    var store = ActorStore.init();
    const enemy = enemy_mod.Enemy{
        .position = .{ .x = 1, .y = 1 },
    };
    var i: usize = 0;
    while (i < config.max_enemies) : (i += 1) {
        const id = store.addEnemy(enemy);
        try std.testing.expect(id != null);
    }
    // Now at capacity — next add must return null
    const overflow = store.addEnemy(enemy);
    try std.testing.expect(overflow == null);
}

test "enemiesSlice length matches enemyCount" {
    var store = ActorStore.init();
    _ = store.addEnemy(.{ .position = .{ .x = 1, .y = 1 }, .glyph = 'g', .name = "goblin", .alive = true });
    _ = store.addEnemy(.{ .position = .{ .x = 2, .y = 2 }, .glyph = 'o', .name = "orc", .alive = true });
    try std.testing.expectEqual(store.enemyCount(), store.enemiesSlice().len);
}
