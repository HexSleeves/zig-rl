const config = @import("../config.zig");
const tile = @import("tile.zig");

pub const Map = struct {
    pub const tile_count = config.map_width * config.map_height;

    width: usize = config.map_width,
    height: usize = config.map_height,
    tiles: [tile_count]tile.Tile,

    pub fn filled(fill_tile: tile.Tile) Map {
        return .{
            .tiles = [_]tile.Tile{fill_tile} ** tile_count,
        };
    }

    pub fn inBounds(self: *const Map, x: i32, y: i32) bool {
        return x >= 0 and y >= 0 and x < @as(i32, @intCast(self.width)) and y < @as(i32, @intCast(self.height));
    }

    pub fn isBlocked(self: *const Map, x: usize, y: usize) bool {
        if (x >= self.width or y >= self.height) return true;
        return self.tiles[self.index(x, y)].blocksMovement();
    }

    pub fn isBlockedAt(self: *const Map, x: i32, y: i32) bool {
        if (!self.inBounds(x, y)) return true;
        return self.isBlocked(@intCast(x), @intCast(y));
    }

    pub fn set(self: *Map, x: usize, y: usize, value: tile.Tile) void {
        if (x >= self.width or y >= self.height) return;
        self.tiles[self.index(x, y)] = value;
    }

    pub fn get(self: *const Map, x: usize, y: usize) tile.Tile {
        if (x >= self.width or y >= self.height) return tile.Tile.wall();
        return self.tiles[self.index(x, y)];
    }

    fn index(self: *const Map, x: usize, y: usize) usize {
        return y * self.width + x;
    }
};
