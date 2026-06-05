const State = @import("state.zig").State;
const input = @import("input.zig");
const movement = @import("systems/movement.zig");
const turn = @import("systems/turn.zig");

pub const Game = struct {
    state: State,

    pub fn init(allocator: anytype) !Game {
        var game = Game{ .state = State.init(allocator) };
        try game.state.log.add("Explore the starter dungeon.");
        return game;
    }

    pub fn deinit(self: *Game) void {
        self.state.deinit();
    }

    pub fn handle(self: *Game, command: input.Command) !void {
        switch (command) {
            .move => |direction| _ = try movement.tryMovePlayer(&self.state, direction),
            .wait => {
                try self.state.log.add("You wait.");
                try turn.endPlayerTurn(&self.state);
            },
            .quit => self.state.quit_requested = true,
            .none => try self.state.log.add("Unknown command."),
        }
    }
};
