const entity = @import("../entities/entity.zig");
const State = @import("../state.zig").State;
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

pub fn tryMovePlayer(state: *State, direction: Direction) !MoveResult {
    const next = state.run.player.position.translated(direction.delta());
    if (state.run.map.isBlockedAt(next.x, next.y)) {
        try state.run.log.add("You run into a wall.");
        return .blocked;
    }

    state.run.player.position = next;
    try turn.endPlayerTurn(state);
    return .moved;
}
