const std = @import("std");
const app = @import("app.zig");

pub fn main(init: std.process.Init) !void {
    var debug_allocator = std.heap.DebugAllocator(.{}){};
    defer _ = debug_allocator.deinit();

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.skip();

    var options = app.RunOptions{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--smoke-test")) {
            options.smoke_frames = 5;
        }
    }

    try app.run(debug_allocator.allocator(), init.io, options);
}
