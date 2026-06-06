const State = @import("../state.zig").State;
const RunState = @import("../run_state.zig").RunState;

/// End the player turn using a RunState pointer directly.
pub fn endPlayerTurn(run: *RunState) !void {
    run.turn_count += 1;
    if (run.turn_count == 1) {
        try run.log.add("The dungeon waits.");
    }
}

/// Backward-compat wrapper: end player turn from a full State.
pub fn endPlayerTurnState(state: *State) !void {
    try endPlayerTurn(&state.run);
}
