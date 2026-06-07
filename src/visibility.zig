const std = @import("std");
const config = @import("config.zig");
const map_mod = @import("world/map.zig");

pub const TOTAL_CELLS = config.map_width * config.map_height;

pub const VisibilityMap = struct {
    visible: [TOTAL_CELLS]bool,
    explored: [TOTAL_CELLS]bool,

    pub fn init() VisibilityMap {
        return .{
            .visible = [_]bool{false} ** TOTAL_CELLS,
            .explored = [_]bool{false} ** TOTAL_CELLS,
        };
    }

    pub fn isVisible(self: *const VisibilityMap, x: i32, y: i32) bool {
        if (x < 0 or y < 0 or x >= @as(i32, config.map_width) or y >= @as(i32, config.map_height)) return false;
        return self.visible[idx(x, y)];
    }

    pub fn isExplored(self: *const VisibilityMap, x: i32, y: i32) bool {
        if (x < 0 or y < 0 or x >= @as(i32, config.map_width) or y >= @as(i32, config.map_height)) return false;
        return self.explored[idx(x, y)];
    }

    /// Recompute FOV from (ox, oy) with given radius using symmetric shadowcasting.
    pub fn compute(self: *VisibilityMap, map: *const map_mod.Map, ox: i32, oy: i32, radius: u32) void {
        for (&self.visible) |*v| v.* = false;

        if (!map.inBounds(ox, oy)) return;

        self.markVisible(ox, oy);
        if (radius == 0) return;

        var quadrant: u3 = 0;
        while (quadrant < 4) : (quadrant += 1) {
            scan(self, map, ox, oy, radius, quadrant, Row{
                .depth = 1,
                .start_slope = Slope.init(-1, 1),
                .end_slope = Slope.init(1, 1),
            });
        }
    }

    fn markVisible(self: *VisibilityMap, x: i32, y: i32) void {
        const i = idx(x, y);
        self.visible[i] = true;
        self.explored[i] = true;
    }
};

inline fn idx(x: i32, y: i32) usize {
    return @intCast(y * @as(i32, config.map_width) + x);
}

pub fn hasLineOfSight(map: *const map_mod.Map, x0: i32, y0: i32, x1: i32, y1: i32) bool {
    if (!map.inBounds(x0, y0) or !map.inBounds(x1, y1)) return false;
    var vm = VisibilityMap.init();
    vm.compute(map, x0, y0, @intCast(config.map_width + config.map_height));
    return vm.isVisible(x1, y1);
}

const Slope = struct {
    num: i32,
    den: i32,

    fn init(num: i32, den: i32) Slope {
        std.debug.assert(den > 0);
        return .{ .num = num, .den = den };
    }
};

const Row = struct {
    depth: i32,
    start_slope: Slope,
    end_slope: Slope,

    fn minCol(self: Row) i32 {
        return roundTiesUp(@as(i64, self.depth) * self.start_slope.num, self.start_slope.den);
    }

    fn maxCol(self: Row) i32 {
        return roundTiesDown(@as(i64, self.depth) * self.end_slope.num, self.end_slope.den);
    }

    fn next(self: Row) Row {
        return .{
            .depth = self.depth + 1,
            .start_slope = self.start_slope,
            .end_slope = self.end_slope,
        };
    }
};

const ScanTile = struct {
    depth: i32,
    col: i32,
};

fn scan(vis: *VisibilityMap, map: *const map_mod.Map, ox: i32, oy: i32, radius: u32, quadrant: u3, row_in: Row) void {
    if (row_in.depth > @as(i32, @intCast(radius))) return;

    var row = row_in;
    var prev_tile: ?ScanTile = null;
    var col = row.minCol();
    const max_col = row.maxCol();
    while (col <= max_col) : (col += 1) {
        const tile = ScanTile{ .depth = row.depth, .col = col };
        if (isWall(map, ox, oy, radius, quadrant, tile) or isSymmetric(row, tile)) {
            reveal(vis, map, ox, oy, radius, quadrant, tile);
        }

        if (isWall(map, ox, oy, radius, quadrant, prev_tile) and isFloor(map, ox, oy, radius, quadrant, tile)) {
            row.start_slope = slope(tile);
        }

        if (isFloor(map, ox, oy, radius, quadrant, prev_tile) and isWall(map, ox, oy, radius, quadrant, tile)) {
            var next_row = row.next();
            next_row.end_slope = slope(tile);
            scan(vis, map, ox, oy, radius, quadrant, next_row);
        }

        prev_tile = tile;
    }

    if (isFloor(map, ox, oy, radius, quadrant, prev_tile)) {
        scan(vis, map, ox, oy, radius, quadrant, row.next());
    }
}

fn reveal(vis: *VisibilityMap, map: *const map_mod.Map, ox: i32, oy: i32, radius: u32, quadrant: u3, tile: ScanTile) void {
    const pos = transform(ox, oy, quadrant, tile);
    if (map.inBounds(pos[0], pos[1]) and inRadius(ox, oy, pos[0], pos[1], radius)) {
        vis.markVisible(pos[0], pos[1]);
    }
}

fn isWall(map: *const map_mod.Map, ox: i32, oy: i32, radius: u32, quadrant: u3, maybe_tile: ?ScanTile) bool {
    const tile = maybe_tile orelse return false;
    const pos = transform(ox, oy, quadrant, tile);
    if (!map.inBounds(pos[0], pos[1]) or !inRadius(ox, oy, pos[0], pos[1], radius)) return false;
    return map.get(@intCast(pos[0]), @intCast(pos[1])).blocks_sight;
}

fn isFloor(map: *const map_mod.Map, ox: i32, oy: i32, radius: u32, quadrant: u3, maybe_tile: ?ScanTile) bool {
    const tile = maybe_tile orelse return false;
    return !isWall(map, ox, oy, radius, quadrant, tile);
}

fn transform(ox: i32, oy: i32, quadrant: u3, tile: ScanTile) [2]i32 {
    return switch (quadrant) {
        0 => .{ ox + tile.col, oy - tile.depth },
        1 => .{ ox + tile.depth, oy + tile.col },
        2 => .{ ox + tile.col, oy + tile.depth },
        3 => .{ ox - tile.depth, oy + tile.col },
        else => unreachable,
    };
}

fn inRadius(ox: i32, oy: i32, x: i32, y: i32, radius: u32) bool {
    const dx = x - ox;
    const dy = y - oy;
    const r: i32 = @intCast(radius);
    return dx * dx + dy * dy <= r * r;
}

fn slope(tile: ScanTile) Slope {
    return Slope.init(2 * tile.col - 1, 2 * tile.depth);
}

fn isSymmetric(row: Row, tile: ScanTile) bool {
    return compareIntToScaledSlope(tile.col, row.depth, row.start_slope) >= 0 and
        compareIntToScaledSlope(tile.col, row.depth, row.end_slope) <= 0;
}

fn compareIntToScaledSlope(value: i32, depth: i32, s: Slope) i32 {
    const lhs = @as(i64, value) * s.den;
    const rhs = @as(i64, depth) * s.num;
    if (lhs < rhs) return -1;
    if (lhs > rhs) return 1;
    return 0;
}

fn roundTiesUp(num: i64, den: i32) i32 {
    const d = @as(i64, den) * 2;
    return @intCast(@divFloor(num * 2 + den, d));
}

fn roundTiesDown(num: i64, den: i32) i32 {
    const d = @as(i64, den) * 2;
    return @intCast(-@divFloor(-(num * 2 - den), d));
}

// --- Tests ---

test "init: all false" {
    const vm = VisibilityMap.init();
    for (vm.visible) |v| try std.testing.expect(!v);
    for (vm.explored) |e| try std.testing.expect(!e);
}

test "compute: origin tile is visible" {
    const tile_mod = @import("world/tile.zig");
    var map = map_mod.Map.filled(tile_mod.Tile.floor());
    var vm = VisibilityMap.init();
    vm.compute(&map, 5, 5, 6);
    try std.testing.expect(vm.isVisible(5, 5));
}

test "compute: explored tiles persist after second compute" {
    const tile_mod = @import("world/tile.zig");
    var map = map_mod.Map.filled(tile_mod.Tile.floor());
    var vm = VisibilityMap.init();
    vm.compute(&map, 5, 5, 6);
    // After first compute, (5,5) is explored
    try std.testing.expect(vm.isExplored(5, 5));
    // Second compute from different origin
    vm.compute(&map, 20, 15, 6);
    // (5,5) should no longer be visible but still explored
    try std.testing.expect(!vm.isVisible(5, 5));
    try std.testing.expect(vm.isExplored(5, 5));
    // New origin should be visible
    try std.testing.expect(vm.isVisible(20, 15));
}

test "isVisible: out-of-bounds returns false" {
    const vm = VisibilityMap.init();
    try std.testing.expect(!vm.isVisible(-1, 0));
    try std.testing.expect(!vm.isVisible(0, -1));
    try std.testing.expect(!vm.isVisible(@as(i32, config.map_width), 0));
    try std.testing.expect(!vm.isVisible(0, @as(i32, config.map_height)));
}

test "compute: wall adjacent to origin is visible but blocks further sight" {
    const tile_mod = @import("world/tile.zig");
    // Fill with floors, place a wall at (6,5) — directly east of origin (5,5)
    var map = map_mod.Map.filled(tile_mod.Tile.floor());
    map.set(6, 5, tile_mod.Tile.wall());
    var vm = VisibilityMap.init();
    vm.compute(&map, 5, 5, 10);
    // The wall itself should be visible
    try std.testing.expect(vm.isVisible(6, 5));
    // Tile directly behind the wall (7,5) should NOT be visible
    try std.testing.expect(!vm.isVisible(7, 5));
}

test "compute: floor visibility is symmetric around blockers" {
    const lines = [_][]const u8{
        "############",
        "##....#....#",
        "#.##.......#",
        "#.....#....#",
        "##.##...####",
        "#..........#",
        "##.#.......#",
        "#.#........#",
        "#.......#..#",
        "##.........#",
        "#.#.#.....##",
        "############",
    };
    var map = mapFromLines(&lines);

    var from_a = VisibilityMap.init();
    from_a.compute(&map, 2, 1, 8);

    var from_b = VisibilityMap.init();
    from_b.compute(&map, 7, 3, 8);

    try std.testing.expectEqual(from_a.isVisible(7, 3), from_b.isVisible(2, 1));
}

test "compute: line-clear floor target is visible" {
    const lines = [_][]const u8{
        "############",
        "#....#...#.#",
        "#..#.......#",
        "#......##..#",
        "##...#.....#",
        "#.#.#.....##",
        "#...#....#.#",
        "##....#....#",
        "#........###",
        "#.#..#.....#",
        "##....#....#",
        "############",
    };
    var map = mapFromLines(&lines);

    var vm = VisibilityMap.init();
    vm.compute(&map, 7, 2, 8);
    try std.testing.expect(vm.isVisible(4, 7));
}

fn mapFromLines(lines: []const []const u8) map_mod.Map {
    const tile_mod = @import("world/tile.zig");
    var map = map_mod.Map.filled(tile_mod.Tile.floor());
    for (lines, 0..) |line, y| {
        for (line, 0..) |ch, x| {
            if (ch == '#') {
                map.set(x, y, tile_mod.Tile.wall());
            }
        }
    }
    return map;
}
