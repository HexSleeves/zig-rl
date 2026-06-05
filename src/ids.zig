const std = @import("std");

/// Identifies actors (player, enemies, NPCs)
pub const ActorId = struct {
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

/// Identifies items in the world/inventory
pub const ItemId = struct {
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

/// Identifies a map cell (flat index into tile array, 0..width*height-1)
pub const CellIndex = struct {
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

/// Identifies content definitions (actor templates, item templates)
pub const DefinitionId = struct {
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

/// Identifies factions (player, security, rogue_machines, etc.)
pub const FactionId = struct {
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

/// Identifies abilities/skills
pub const AbilityId = struct {
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

/// Identifies status effects
pub const EffectId = struct {
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

/// The player is always actor 0
pub const PLAYER_ACTOR_ID = ActorId{ .value = 0 };

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

test "PLAYER_ACTOR_ID is valid" {
    try std.testing.expect(PLAYER_ACTOR_ID.isValid());
}
