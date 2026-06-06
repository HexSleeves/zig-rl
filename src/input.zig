const movement = @import("systems/movement.zig");

pub const Command = union(enum) {
    move: movement.Direction,
    wait,
    quit,
    pickup,
    hack,
    none,
};

pub fn parse(byte: u8) Command {
    return switch (byte) {
        'w', 'W', 'k', 'K' => .{ .move = .north },
        's', 'S', 'j', 'J' => .{ .move = .south },
        'a', 'A', 'l', 'L' => .{ .move = .west },
        'd', 'D' => .{ .move = .east },
        '.', ' ' => .wait,
        'q', 'Q' => .quit,
        'g', 'G' => .pickup,
        'h', 'H' => .hack,
        else => .none,
    };
}
