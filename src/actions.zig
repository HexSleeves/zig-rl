const movement = @import("systems/movement.zig");
const input = @import("input.zig");
const RunState = @import("run_state.zig").RunState;
const turn = @import("systems/turn.zig");

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

/// Convert an input Command to an ActionIntent.
/// Returns null for .none (no-op inputs).
pub fn intentFromCommand(cmd: input.Command) ?ActionIntent {
    return switch (cmd) {
        .move => |dir| .{ .move = dir },
        .wait => .wait,
        .quit => .quit,
        .none => null,
    };
}

/// Validate an ActionIntent against the current RunState.
/// Returns a ready-to-execute Action, or null if the action is impossible
/// (e.g. moving into a wall).
pub fn validateIntent(intent: ActionIntent, run: *const RunState) ?Action {
    return switch (intent) {
        .move => |dir| blk: {
            const delta = movement.Direction.delta(dir);
            const new_x = run.player.position.x + delta.x;
            const new_y = run.player.position.y + delta.y;
            if (run.map.isBlockedAt(new_x, new_y)) break :blk null;
            // Enemy present at target tile: becomes a melee bump instead
            if (run.actors.glyphAt(new_x, new_y) != null) break :blk .{ .melee_bump = dir };
            break :blk .{ .move = dir };
        },
        .wait => .wait,
        .melee_bump => |dir| .{ .melee_bump = dir },
        .quit => .quit,
    };
}

/// Execute a validated Action against RunState.
/// Quit must be handled at the State level before calling this.
pub fn executeAction(action: Action, run: *RunState) !void {
    switch (action) {
        .move => |dir| {
            _ = try movement.tryMovePlayerRun(run, dir);
        },
        .wait => {
            try run.log.add("You wait.");
            try turn.endPlayerTurn(run);
        },
        .melee_bump => |dir| {
            _ = dir; // direction unused until M2 combat
            try run.log.add("You bump into the enemy.");
            run.turn_count += 1;
        },
        .quit => {}, // handled at State level
    }
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
