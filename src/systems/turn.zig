const State = @import("../state.zig").State;

pub fn endPlayerTurn(state: *State) !void {
    state.turn_count += 1;
    if (state.turn_count == 1) {
        try state.log.add("The dungeon waits.");
    }
}
