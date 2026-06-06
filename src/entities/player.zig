const entity = @import("entity.zig");
const config = @import("../config.zig");
const inventory_mod = @import("../items/inventory.zig");

pub const Player = struct {
    position: entity.Position = .{
        .x = config.player_start_x,
        .y = config.player_start_y,
    },
    glyph: u8 = '@',
    hp: i32 = 20,
    max_hp: i32 = 20,
    armor: u32 = 0,
    evasion: u32 = 15,
    inventory: inventory_mod.Inventory = .{},
};
