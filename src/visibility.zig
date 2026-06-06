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

    /// Recompute FOV from (ox, oy) with given radius using recursive shadowcasting.
    pub fn compute(self: *VisibilityMap, map: *const map_mod.Map, ox: i32, oy: i32, radius: u32) void {
        // Clear visible
        for (&self.visible) |*v| v.* = false;

        // Mark origin visible and explored
        if (map.inBounds(ox, oy)) {
            self.visible[idx(ox, oy)] = true;
            self.explored[idx(ox, oy)] = true;
        }

        // Process all 8 octants
        // Octant transforms: (xx, xy, yx, yy)
        const octants = [8][4]i32{
            .{ 1,  0,  0,  1 },
            .{ 0,  1,  1,  0 },
            .{ 0, -1,  1,  0 },
            .{ -1, 0,  0,  1 },
            .{ -1, 0,  0, -1 },
            .{ 0, -1, -1,  0 },
            .{ 0,  1, -1,  0 },
            .{ 1,  0,  0, -1 },
        };

        for (octants) |o| {
            castLight(self, map, ox, oy, radius, 1, 1.0, 0.0, o[0], o[1], o[2], o[3]);
        }
    }
};

inline fn idx(x: i32, y: i32) usize {
    return @intCast(y * @as(i32, config.map_width) + x);
}

/// Recursive shadowcasting for one octant.
/// xx, xy, yx, yy are the octant transform matrix.
fn castLight(
    vis: *VisibilityMap,
    map: *const map_mod.Map,
    ox: i32,
    oy: i32,
    radius: u32,
    row: i32,
    start_slope: f32,
    end_slope: f32,
    xx: i32,
    xy: i32,
    yx: i32,
    yy: i32,
) void {
    if (start_slope < end_slope) return;

    const r2 = @as(i32, @intCast(radius * radius));
    var new_start: f32 = 0.0;
    var blocked = false;
    var j = row;

    while (j <= @as(i32, @intCast(radius)) and !blocked) : (j += 1) {
        var dx: i32 = -j;
        while (dx <= 0) : (dx += 1) {
            const dy: i32 = -j;
            // Left and right slopes for this cell
            const l_slope: f32 = (@as(f32, @floatFromInt(dx)) - 0.5) / (@as(f32, @floatFromInt(dy)) + 0.5);
            const r_slope: f32 = (@as(f32, @floatFromInt(dx)) + 0.5) / (@as(f32, @floatFromInt(dy)) - 0.5);

            if (start_slope < r_slope) continue;
            if (end_slope > l_slope) break;

            // Transform to map coordinates
            const mx: i32 = ox + dx * xx + dy * xy;
            const my: i32 = oy + dx * yx + dy * yy;

            // Check radius (distance squared)
            if (dx * dx + dy * dy <= r2 and map.inBounds(mx, my)) {
                const i = idx(mx, my);
                vis.visible[i] = true;
                vis.explored[i] = true;
            }

            if (blocked) {
                if (!map.inBounds(mx, my) or map.get(@intCast(mx), @intCast(my)).blocks_sight) {
                    new_start = r_slope;
                } else {
                    blocked = false;
                }
            } else {
                if (map.inBounds(mx, my) and map.get(@intCast(mx), @intCast(my)).blocks_sight and j < @as(i32, @intCast(radius))) {
                    blocked = true;
                    castLight(vis, map, ox, oy, radius, j + 1, start_slope, l_slope, xx, xy, yx, yy);
                    new_start = r_slope;
                }
            }
        }
        if (blocked) {
            start_slope = new_start;
        }
    }
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
