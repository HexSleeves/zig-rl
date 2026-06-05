const entity = @import("entity.zig");

pub const Enemy = struct {
    position: entity.Position,
    glyph: u8 = 'g',
    name: []const u8 = "goblin",
    alive: bool = true,
};
