pub const TileKind = enum {
    wall,
    floor,
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

    pub fn blocksMovement(self: Tile) bool {
        return self.kind == .wall;
    }

    pub fn glyph(self: Tile) u8 {
        return switch (self.kind) {
            .wall => '#',
            .floor => '.',
        };
    }
};
