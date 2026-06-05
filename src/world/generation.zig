const config = @import("../config.zig");
const map_mod = @import("map.zig");
const tile = @import("tile.zig");

const Room = struct {
    x1: usize,
    y1: usize,
    x2: usize,
    y2: usize,
};

pub fn generateStarterDungeon() map_mod.Map {
    var map = map_mod.Map.filled(tile.Tile.wall());

    digRoom(&map, .{ .x1 = 1, .y1 = 1, .x2 = 17, .y2 = 10 });
    digRoom(&map, .{ .x1 = 23, .y1 = 8, .x2 = config.map_width - 1, .y2 = 18 });
    digHorizontalTunnel(&map, 16, 24, 6);
    digVerticalTunnel(&map, 6, 12, 24);

    map.set(@intCast(config.player_start_x), @intCast(config.player_start_y), tile.Tile.floor());
    return map;
}

fn digRoom(map: *map_mod.Map, room: Room) void {
    var y = room.y1;
    while (y < room.y2) : (y += 1) {
        var x = room.x1;
        while (x < room.x2) : (x += 1) {
            map.set(x, y, tile.Tile.floor());
        }
    }
}

fn digHorizontalTunnel(map: *map_mod.Map, x1: usize, x2: usize, y: usize) void {
    var x = x1;
    while (x <= x2) : (x += 1) {
        map.set(x, y, tile.Tile.floor());
    }
}

fn digVerticalTunnel(map: *map_mod.Map, y1: usize, y2: usize, x: usize) void {
    var y = y1;
    while (y <= y2) : (y += 1) {
        map.set(x, y, tile.Tile.floor());
    }
}
