const movement = @import("systems/movement.zig");

pub const Command = union(enum) {
    move: movement.Direction,
    wait,
    quit,
    none,
};

pub fn parse(byte: u8) Command {
    return switch (byte) {
        'w', 'W', 'k', 'K' => .{ .move = .north },
        's', 'S', 'j', 'J' => .{ .move = .south },
        'a', 'A', 'h', 'H' => .{ .move = .west },
        'd', 'D', 'l', 'L' => .{ .move = .east },
        '.', ' ' => .wait,
        'q', 'Q' => .quit,
        else => .none,
    };
}
