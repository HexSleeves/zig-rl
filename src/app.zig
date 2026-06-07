const std = @import("std");
const Io = std.Io;
const Game = @import("game.zig").Game;
const window = @import("window.zig");

pub const RunOptions = struct {
    smoke_frames: ?u32 = null,
};

pub fn run(allocator: std.mem.Allocator, io: Io, options: RunOptions) !void {
    var game = try Game.init(allocator, io);
    defer game.deinit();

    try window.run(&game, options.smoke_frames);
}
