pub const TileKind = enum {
    wall,
    floor,
    door,
};

pub const Tile = struct {
    kind: TileKind,
    blocks_sight: bool,

    pub fn wall() Tile {
        return .{ .kind = .wall, .blocks_sight = true };
    }

    pub fn floor() Tile {
        return .{ .kind = .floor, .blocks_sight = false };
    }

    pub fn door_closed() Tile {
        return .{ .kind = .door, .blocks_sight = true };
    }

    pub fn door_open() Tile {
        return .{ .kind = .door, .blocks_sight = false };
    }

    pub fn blocksMovement(self: Tile) bool {
        return self.kind == .wall or (self.kind == .door and self.blocks_sight);
    }

    pub fn glyph(self: Tile) u8 {
        return switch (self.kind) {
            .wall => '#',
            .floor => '.',
            .door => '+',
        };
    }
};
