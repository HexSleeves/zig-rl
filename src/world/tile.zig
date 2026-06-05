pub const TileKind = enum {
    wall,
    floor,
};

pub const Tile = struct {
    kind: TileKind,

    pub fn wall() Tile {
        return .{ .kind = .wall };
    }

    pub fn floor() Tile {
        return .{ .kind = .floor };
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
