const State = @import("../state.zig").State;

pub fn endPlayerTurn(state: *State) !void {
    state.run.turn_count += 1;
    if (state.run.turn_count == 1) {
        try state.run.log.add("The dungeon waits.");
    }
}
