const std = @import("std");
const config = @import("../config.zig");

pub const MessageLog = struct {
    allocator: std.mem.Allocator,
    entries: [config.max_log_messages][]u8 = undefined,
    len: usize = 0,

    pub fn init(allocator: std.mem.Allocator) MessageLog {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *MessageLog) void {
        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            self.allocator.free(self.entries[i]);
        }
        self.len = 0;
    }

    pub fn add(self: *MessageLog, message: []const u8) !void {
        const copy = try self.allocator.dupe(u8, message);
        if (self.len == config.max_log_messages) {
            self.allocator.free(self.entries[0]);
            var i: usize = 1;
            while (i < self.len) : (i += 1) {
                self.entries[i - 1] = self.entries[i];
            }
            self.len -= 1;
        }
        self.entries[self.len] = copy;
        self.len += 1;
    }

    pub fn count(self: *const MessageLog) usize {
        return self.len;
    }

    pub fn at(self: *const MessageLog, index: usize) []const u8 {
        return self.entries[index];
    }
};
