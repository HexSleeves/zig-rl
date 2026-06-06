const std = @import("std");
const config = @import("../config.zig");
const camera = @import("camera.zig");

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,
    pub fn right(self: Rect) i32 {
        return self.x + self.w;
    }
    pub fn bottom(self: Rect) i32 {
        return self.y + self.h;
    }
};

pub const Layout = struct {
    scale: f32,
    tile_size: i32,
    window_width: i32,
    window_height: i32,
    header: Rect,
    sidebar: Rect,
    map: Rect,
    inspect: Rect,
    log: Rect,

    pub fn viewport(self: Layout) camera.Viewport {
        return .{
            .origin_x = self.map.x,
            .origin_y = self.map.y,
            .tiles_w = @divFloor(self.map.w, self.tile_size),
            .tiles_h = @divFloor(self.map.h, self.tile_size),
            .tile_size = self.tile_size,
        };
    }
};

fn s(value: i32, scale: f32) i32 {
    return @intFromFloat(@round(@as(f32, @floatFromInt(value)) * scale));
}

pub fn layout() Layout {
    return layoutForScale(1.0);
}

pub fn layoutForScale(scale: f32) Layout {
    const pad = s(config.ui_padding, scale);
    const gap = s(config.ui_gap, scale);
    const header_h = s(config.ui_header_h, scale);
    const sidebar_w = s(config.ui_sidebar_w, scale);
    const inspect_w = s(config.ui_inspect_w, scale);
    const log_h = s(config.ui_log_h, scale);
    const tile = s(@intCast(config.tile_size_pixels), scale);
    const map_w = config.ui_viewport_tiles_w * tile;
    const map_h = config.ui_viewport_tiles_h * tile;

    const content_top = pad + header_h + gap;
    const map_x = pad + sidebar_w + gap;
    const inspect_x = map_x + map_w + gap;
    const window_width = inspect_x + inspect_w + pad;
    const window_height = content_top + map_h + gap + log_h + pad;

    return .{
        .scale = scale,
        .tile_size = tile,
        .window_width = window_width,
        .window_height = window_height,
        .header = .{ .x = pad, .y = pad, .w = window_width - pad * 2, .h = header_h },
        .sidebar = .{ .x = pad, .y = content_top, .w = sidebar_w, .h = map_h },
        .map = .{ .x = map_x, .y = content_top, .w = map_w, .h = map_h },
        .inspect = .{ .x = inspect_x, .y = content_top, .w = inspect_w, .h = map_h },
        .log = .{ .x = pad, .y = content_top + map_h + gap, .w = window_width - pad * 2, .h = log_h },
    };
}

test "layout regions fit inside window with no horizontal overlap" {
    const l = layout();
    try std.testing.expect(l.sidebar.right() <= l.map.x);
    try std.testing.expect(l.map.right() <= l.inspect.x);
    try std.testing.expect(l.inspect.right() <= l.window_width);
    try std.testing.expect(l.log.bottom() <= l.window_height);
    try std.testing.expect(l.header.bottom() <= l.map.y);
}

test "viewport derives tile counts from map rect" {
    const l = layout();
    const vp = l.viewport();
    try std.testing.expectEqual(config.ui_viewport_tiles_w, vp.tiles_w);
    try std.testing.expectEqual(config.ui_viewport_tiles_h, vp.tiles_h);
}

test "scale grows the window" {
    const a = layout();
    const b = layoutForScale(2.0);
    try std.testing.expect(b.window_width > a.window_width);
    try std.testing.expect(b.tile_size == a.tile_size * 2);
}
