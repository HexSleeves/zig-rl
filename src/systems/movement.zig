const entity = @import("../entities/entity.zig");
const State = @import("../state.zig").State;
const RunState = @import("../run_state.zig").RunState;
const turn = @import("turn.zig");

pub const Direction = enum {
    north,
    south,
    west,
    east,

    pub fn delta(self: Direction) entity.Position {
        return switch (self) {
            .north => .{ .x = 0, .y = -1 },
            .south => .{ .x = 0, .y = 1 },
            .west => .{ .x = -1, .y = 0 },
            .east => .{ .x = 1, .y = 0 },
        };
    }
};

pub const MoveResult = enum {
    moved,
    blocked,
};

/// Move the player using a RunState pointer directly.
pub fn tryMovePlayerRun(run: *RunState, direction: Direction) !MoveResult {
    const next = run.player.position.translated(direction.delta());
    if (run.map.isBlockedAt(next.x, next.y)) {
        try run.log.add("You run into a wall.");
        return .blocked;
    }

    run.player.position = next;
    try turn.endPlayerTurn(run);
    return .moved;
}

/// Backward-compat wrapper: move player from a full State.
pub fn tryMovePlayer(state: *State, direction: Direction) !MoveResult {
    return tryMovePlayerRun(&state.run, direction);
}
