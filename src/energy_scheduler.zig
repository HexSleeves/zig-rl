const std = @import("std");
const ids = @import("ids.zig");
const config = @import("config.zig");

pub const ACTION_THRESHOLD: u32 = 100;
pub const BASE_SPEED: u32 = 100;

/// Per-actor energy entry
pub const ActorEnergy = struct {
    id: ids.ActorId,
    energy: i32, // signed: can go negative after expensive actions
    speed: u32, // energy gained per scheduler tick
};

/// Fixed-capacity energy scheduler.
/// Slot 0 = player (ids.player_actor_id).
/// Slots 1..max_enemies = enemy slots matching ActorStore indices.
pub const EnergyScheduler = struct {
    actors: [1 + config.max_enemies]ActorEnergy, // +1 for player
    count: usize, // active actor count (1 player + enemy_count)

    pub fn init() EnergyScheduler {
        var sched = EnergyScheduler{
            .actors = std.mem.zeroes([1 + config.max_enemies]ActorEnergy),
            .count = 1,
        };
        // Player at slot 0: starts with ACTION_THRESHOLD so they act first
        sched.actors[0] = ActorEnergy{
            .id = ids.player_actor_id,
            .energy = @intCast(ACTION_THRESHOLD),
            .speed = BASE_SPEED,
        };
        return sched;
    }

    /// Register an enemy actor with given speed.
    pub fn addActor(self: *EnergyScheduler, id: ids.ActorId, speed: u32) void {
        if (self.count >= self.actors.len) return;
        self.actors[self.count] = ActorEnergy{
            .id = id,
            .energy = 0,
            .speed = speed,
        };
        self.count += 1;
    }

    /// Remove an actor (on death). Shifts remaining slots down.
    pub fn removeActor(self: *EnergyScheduler, id: ids.ActorId) void {
        // Never remove slot 0 (player)
        var found_idx: ?usize = null;
        var i: usize = 1;
        while (i < self.count) : (i += 1) {
            if (self.actors[i].id.eql(id)) {
                found_idx = i;
                break;
            }
        }
        const idx = found_idx orelse return;
        // Shift everything after idx down by one
        var j: usize = idx;
        while (j + 1 < self.count) : (j += 1) {
            self.actors[j] = self.actors[j + 1];
        }
        self.count -= 1;
    }

    /// Returns true if the actor has enough energy to take an action.
    pub fn canAct(self: *const EnergyScheduler, id: ids.ActorId) bool {
        for (self.actors[0..self.count]) |*entry| {
            if (entry.id.eql(id)) {
                return entry.energy >= @as(i32, @intCast(ACTION_THRESHOLD));
            }
        }
        return false;
    }

    /// Deduct energy cost from actor after they act.
    pub fn deductCost(self: *EnergyScheduler, id: ids.ActorId, cost: u32) void {
        for (self.actors[0..self.count]) |*entry| {
            if (entry.id.eql(id)) {
                entry.energy -= @as(i32, @intCast(cost));
                return;
            }
        }
    }

    /// Advance all actors by their speed until at least one actor
    /// has >= ACTION_THRESHOLD energy.
    /// Returns the ActorId of the next actor that should act.
    /// Player always gets priority when tied.
    pub fn nextActor(self: *EnergyScheduler) ids.ActorId {
        // If player can already act, return immediately
        if (self.actors[0].energy >= @as(i32, @intCast(ACTION_THRESHOLD))) {
            return ids.player_actor_id;
        }

        // Keep ticking until at least one actor can act
        while (true) {
            self.tick();

            // Check player first (priority on ties)
            if (self.actors[0].energy >= @as(i32, @intCast(ACTION_THRESHOLD))) {
                return ids.player_actor_id;
            }

            // Check enemies
            var i: usize = 1;
            while (i < self.count) : (i += 1) {
                if (self.actors[i].energy >= @as(i32, @intCast(ACTION_THRESHOLD))) {
                    return self.actors[i].id;
                }
            }
        }
    }

    /// Tick all actors: each gains their speed in energy.
    fn tick(self: *EnergyScheduler) void {
        for (self.actors[0..self.count]) |*entry| {
            entry.energy += @as(i32, @intCast(entry.speed));
        }
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "player starts with canAct() = true" {
    const sched = EnergyScheduler.init();
    try std.testing.expect(sched.canAct(ids.player_actor_id));
}

test "after deductCost(player, 100), player canAct() = false" {
    var sched = EnergyScheduler.init();
    sched.deductCost(ids.player_actor_id, 100);
    try std.testing.expect(!sched.canAct(ids.player_actor_id));
}

test "after one tick, player regains 100 energy and canAct() = true again" {
    var sched = EnergyScheduler.init();
    sched.deductCost(ids.player_actor_id, 100);
    try std.testing.expect(!sched.canAct(ids.player_actor_id));
    sched.tick();
    try std.testing.expect(sched.canAct(ids.player_actor_id));
}

test "nextActor() returns player_actor_id when player can act" {
    var sched = EnergyScheduler.init();
    const next = sched.nextActor();
    try std.testing.expect(next.eql(ids.player_actor_id));
}

test "addActor increases count" {
    var sched = EnergyScheduler.init();
    try std.testing.expectEqual(@as(usize, 1), sched.count);
    sched.addActor(.{ .value = 1 }, BASE_SPEED);
    try std.testing.expectEqual(@as(usize, 2), sched.count);
    sched.addActor(.{ .value = 2 }, BASE_SPEED);
    try std.testing.expectEqual(@as(usize, 3), sched.count);
}

test "removeActor decreases count" {
    var sched = EnergyScheduler.init();
    sched.addActor(.{ .value = 1 }, BASE_SPEED);
    sched.addActor(.{ .value = 2 }, BASE_SPEED);
    try std.testing.expectEqual(@as(usize, 3), sched.count);
    sched.removeActor(.{ .value = 1 });
    try std.testing.expectEqual(@as(usize, 2), sched.count);
}

test "removeActor on unknown id is a no-op" {
    var sched = EnergyScheduler.init();
    sched.addActor(.{ .value = 1 }, BASE_SPEED);
    try std.testing.expectEqual(@as(usize, 2), sched.count);
    sched.removeActor(.{ .value = 99 });
    try std.testing.expectEqual(@as(usize, 2), sched.count);
}
