const State = @import("../state.zig").State;

pub fn describeBumpAttack(state: *State, target_name: []const u8) !void {
    _ = try state.run.log.add(target_name);
}
