const std = @import("std");

pub const StatusEffect = enum {
    bleeding,
    stunned,
    burning,
    emped,
    jammed_weapon,
    shielded,
    cloaked,
    detected,
};

/// Tracks active status effects and their remaining durations.
/// Duration 0 = inactive. Fixed capacity, no allocation.
pub const StatusSet = struct {
    durations: [8]u8, // indexed by @intFromEnum(StatusEffect)

    pub fn init() StatusSet {
        return .{ .durations = [_]u8{0} ** 8 };
    }

    pub fn apply(self: *StatusSet, effect: StatusEffect, duration: u8) void {
        self.durations[@intFromEnum(effect)] = duration;
    }

    pub fn has(self: *const StatusSet, effect: StatusEffect) bool {
        return self.durations[@intFromEnum(effect)] > 0;
    }

    pub fn tick(self: *StatusSet) void {
        for (&self.durations) |*d| {
            if (d.* > 0) d.* -= 1;
        }
    }

    pub fn clear(self: *StatusSet, effect: StatusEffect) void {
        self.durations[@intFromEnum(effect)] = 0;
    }
};

test "init has no effects" {
    const ss = StatusSet.init();
    inline for (std.meta.fields(StatusEffect)) |f| {
        const effect: StatusEffect = @enumFromInt(f.value);
        try std.testing.expect(!ss.has(effect));
    }
}

test "apply and has" {
    var ss = StatusSet.init();
    ss.apply(.bleeding, 3);
    try std.testing.expect(ss.has(.bleeding));
    try std.testing.expect(!ss.has(.stunned));
}

test "tick decrements durations" {
    var ss = StatusSet.init();
    ss.apply(.burning, 3);
    ss.tick();
    try std.testing.expectEqual(@as(u8, 2), ss.durations[@intFromEnum(StatusEffect.burning)]);
    ss.tick();
    try std.testing.expectEqual(@as(u8, 1), ss.durations[@intFromEnum(StatusEffect.burning)]);
    ss.tick();
    try std.testing.expectEqual(@as(u8, 0), ss.durations[@intFromEnum(StatusEffect.burning)]);
    try std.testing.expect(!ss.has(.burning));
}

test "tick at 0 duration stays 0 no underflow" {
    var ss = StatusSet.init();
    // All durations start at 0
    ss.tick();
    for (ss.durations) |d| {
        try std.testing.expectEqual(@as(u8, 0), d);
    }
}

test "clear removes effect" {
    var ss = StatusSet.init();
    ss.apply(.shielded, 5);
    try std.testing.expect(ss.has(.shielded));
    ss.clear(.shielded);
    try std.testing.expect(!ss.has(.shielded));
}
