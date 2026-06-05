const State = @import("../state.zig").State;

pub fn draw(writer: anytype, state: *const State) !void {
    try writer.print("Turn: {d} | Move: WASD/HJKL | Wait: . | Quit: q\n", .{state.turn_count});
}
