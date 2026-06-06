const std = @import("std");

fn makeId(comptime _: []const u8) type {
    return struct {
        const Self = @This();
        value: u32,

        pub const invalid = Self{ .value = std.math.maxInt(u32) };

        pub fn eql(self: Self, other: Self) bool {
            return self.value == other.value;
        }

        pub fn isValid(self: Self) bool {
            return self.value != invalid.value;
        }
    };
}

/// Identifies actors (player, enemies, NPCs)
pub const ActorId = makeId("ActorId");

/// Identifies items in the world/inventory
pub const ItemId = makeId("ItemId");

/// Identifies a map cell (flat index into tile array, 0..width*height-1)
pub const CellIndex = makeId("CellIndex");

/// Identifies content definitions (actor templates, item templates)
pub const DefinitionId = makeId("DefinitionId");

/// Identifies factions (player, security, rogue_machines, etc.)
pub const FactionId = makeId("FactionId");

/// Identifies abilities/skills
pub const AbilityId = makeId("AbilityId");

/// Identifies status effects
pub const EffectId = makeId("EffectId");

/// Identifies map objects (doors, terminals, cameras, etc.)
pub const ObjectId = makeId("ObjectId");

/// The player is always actor 0
pub const player_actor_id = ActorId{ .value = 0 };

test "ActorId invalid is not valid" {
    try std.testing.expect(!ActorId.invalid.isValid());
}

test "ActorId valid value is valid" {
    const id = ActorId{ .value = 1 };
    try std.testing.expect(id.isValid());
}

test "ActorId eql same value" {
    const a = ActorId{ .value = 42 };
    const b = ActorId{ .value = 42 };
    try std.testing.expect(a.eql(b));
}

test "ActorId eql different values" {
    const a = ActorId{ .value = 1 };
    const b = ActorId{ .value = 2 };
    try std.testing.expect(!a.eql(b));
}

test "player_actor_id is valid" {
    try std.testing.expect(player_actor_id.isValid());
}

test "all Id types: invalid sentinel is not valid" {
    try std.testing.expect(!ItemId.invalid.isValid());
    try std.testing.expect(!CellIndex.invalid.isValid());
    try std.testing.expect(!DefinitionId.invalid.isValid());
    try std.testing.expect(!FactionId.invalid.isValid());
    try std.testing.expect(!AbilityId.invalid.isValid());
    try std.testing.expect(!EffectId.invalid.isValid());
    try std.testing.expect(!ObjectId.invalid.isValid());
}
