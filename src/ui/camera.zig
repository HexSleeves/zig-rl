const std = @import("std");

/// Viewport describes the map render region in pixels and its size in tiles.
pub const Viewport = struct {
    origin_x: i32,
    origin_y: i32,
    tiles_w: i32,
    tiles_h: i32,
    tile_size: i32,
};

/// Camera is the top-left tile coordinate currently shown.
pub const Camera = struct {
    tile_x: i32 = 0,
    tile_y: i32 = 0,
};

/// Center the camera on (px,py), clamped within [0,map_w)x[0,map_h).
/// If the map is smaller than the viewport in an axis, that axis is centered.
pub fn follow(px: i32, py: i32, map_w: i32, map_h: i32, vp: Viewport) Camera {
    return .{
        .tile_x = clampAxis(px, map_w, vp.tiles_w),
        .tile_y = clampAxis(py, map_h, vp.tiles_h),
    };
}

fn clampAxis(center: i32, map_extent: i32, view_extent: i32) i32 {
    if (map_extent <= view_extent) {
        return @divFloor(map_extent - view_extent, 2);
    }
    const desired = center - @divFloor(view_extent, 2);
    const max_start = map_extent - view_extent;
    return std.math.clamp(desired, 0, max_start);
}

pub fn tileToScreen(tile_x: i32, tile_y: i32, cam: Camera, vp: Viewport) [2]i32 {
    return .{
        vp.origin_x + (tile_x - cam.tile_x) * vp.tile_size,
        vp.origin_y + (tile_y - cam.tile_y) * vp.tile_size,
    };
}

pub fn screenToTile(px: i32, py: i32, cam: Camera, vp: Viewport) ?[2]i32 {
    if (px < vp.origin_x or py < vp.origin_y) return null;
    const lx = @divFloor(px - vp.origin_x, vp.tile_size);
    const ly = @divFloor(py - vp.origin_y, vp.tile_size);
    if (lx >= vp.tiles_w or ly >= vp.tiles_h) return null;
    return .{ cam.tile_x + lx, cam.tile_y + ly };
}

const test_vp = Viewport{ .origin_x = 100, .origin_y = 50, .tiles_w = 10, .tiles_h = 8, .tile_size = 24 };

test "follow clamps at left/top edge" {
    const c = follow(0, 0, 40, 25, test_vp);
    try std.testing.expectEqual(@as(i32, 0), c.tile_x);
    try std.testing.expectEqual(@as(i32, 0), c.tile_y);
}

test "follow clamps at right/bottom edge" {
    const c = follow(39, 24, 40, 25, test_vp);
    try std.testing.expectEqual(@as(i32, 30), c.tile_x);
    try std.testing.expectEqual(@as(i32, 17), c.tile_y);
}

test "follow centers on player mid-map" {
    const c = follow(20, 12, 40, 25, test_vp);
    try std.testing.expectEqual(@as(i32, 15), c.tile_x);
    try std.testing.expectEqual(@as(i32, 8), c.tile_y);
}

test "follow centers small map" {
    const c = follow(2, 2, 6, 4, test_vp);
    try std.testing.expectEqual(@as(i32, -2), c.tile_x);
    try std.testing.expectEqual(@as(i32, -2), c.tile_y);
}

test "screenToTile round-trips tileToScreen" {
    const cam = follow(20, 12, 40, 25, test_vp);
    var ty: i32 = 0;
    while (ty < test_vp.tiles_h) : (ty += 1) {
        var tx: i32 = 0;
        while (tx < test_vp.tiles_w) : (tx += 1) {
            const world_x = cam.tile_x + tx;
            const world_y = cam.tile_y + ty;
            const sp = tileToScreen(world_x, world_y, cam, test_vp);
            const back = screenToTile(sp[0] + 1, sp[1] + 1, cam, test_vp).?;
            try std.testing.expectEqual(world_x, back[0]);
            try std.testing.expectEqual(world_y, back[1]);
        }
    }
}

test "screenToTile returns null outside viewport" {
    const cam = Camera{ .tile_x = 0, .tile_y = 0 };
    try std.testing.expect(screenToTile(0, 0, cam, test_vp) == null);
    try std.testing.expect(screenToTile(100 + 10 * 24, 50, cam, test_vp) == null);
}
