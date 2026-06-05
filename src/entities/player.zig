const entity = @import("entity.zig");
const config = @import("../config.zig");

pub const Player = struct {
    position: entity.Position = .{
        .x = config.player_start_x,
        .y = config.player_start_y,
    },
    glyph: u8 = '@',
};
