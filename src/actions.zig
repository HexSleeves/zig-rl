const movement = @import("systems/movement.zig");

pub const Direction = movement.Direction;

/// Raw intent from input — may be invalid (e.g., move into wall).
pub const ActionIntent = union(enum) {
    move: Direction,
    wait,
    /// Attempt to attack in direction (validated to enemy presence).
    melee_bump: Direction,
    quit,
};

/// Validated, ready-to-execute form.
pub const Action = union(enum) {
    move: Direction,
    wait,
    melee_bump: Direction,
    quit,
};

/// Energy costs per action type.
pub const ActionCost = struct {
    pub const move: u32 = 100;
    pub const wait: u32 = 100;
    pub const melee: u32 = 100;
    pub const shoot: u32 = 120;
    pub const reload: u32 = 150;
    pub const hack: u32 = 150;
    pub const heavy: u32 = 200;
};

/// Returns the energy cost of a validated action.
pub fn costOf(action: Action) u32 {
    return switch (action) {
        .move => ActionCost.move,
        .wait => ActionCost.wait,
        .melee_bump => ActionCost.melee,
        .quit => 0,
    };
}

test "costOf wait" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u32, 100), costOf(.wait));
}

test "costOf move north" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u32, 100), costOf(.{ .move = .north }));
}

test "costOf melee_bump north" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u32, 100), costOf(.{ .melee_bump = .north }));
}

test "ActionCost shoot" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u32, 120), ActionCost.shoot);
}

test "ActionCost hack" {
    const std = @import("std");
    try std.testing.expectEqual(@as(u32, 150), ActionCost.hack);
}
