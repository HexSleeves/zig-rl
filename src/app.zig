const std = @import("std");
const Game = @import("game.zig").Game;
const window = @import("window.zig");

pub const RunOptions = struct {
    smoke_frames: ?u32 = null,
};

pub fn run(allocator: std.mem.Allocator, options: RunOptions) !void {
    var game = try Game.init(allocator);
    defer game.deinit();

    try window.run(&game, options.smoke_frames);
}
