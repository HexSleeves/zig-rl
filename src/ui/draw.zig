const std = @import("std");
const zgui = @import("zgui");
const layout = @import("layout.zig");
const theme = @import("theme.zig");

pub const DrawList = zgui.DrawList;
const Rect = layout.Rect;

fn fx(v: i32) f32 {
    return @floatFromInt(v);
}

/// Scale a design-space pixel offset by the layout scale (HiDPI-aware).
pub fn so(v: i32, scale: f32) i32 {
    return @intFromFloat(@round(@as(f32, @floatFromInt(v)) * scale));
}

pub fn fillRect(dl: DrawList, r: Rect, col: u32) void {
    dl.addRectFilled(.{ .pmin = .{ fx(r.x), fx(r.y) }, .pmax = .{ fx(r.right()), fx(r.bottom()) }, .col = col });
}

pub fn strokeRect(dl: DrawList, r: Rect, col: u32) void {
    dl.addRect(.{ .pmin = .{ fx(r.x), fx(r.y) }, .pmax = .{ fx(r.right()), fx(r.bottom()) }, .col = col });
}

pub const PanelOpts = struct {
    fill: ?u32 = theme.palette.panel,
    border: u32 = theme.palette.border,
    brackets: bool = true,
    bracket_col: ?u32 = null,
    bracket_len: i32 = 10,
};

pub fn panel(dl: DrawList, r: Rect, opts: PanelOpts) void {
    if (opts.fill) |f| fillRect(dl, r, f);
    strokeRect(dl, r, opts.border);
    if (opts.brackets) cornerBrackets(dl, r, opts.bracket_len, opts.bracket_col orelse opts.border);
}

fn line(dl: DrawList, x1: i32, y1: i32, x2: i32, y2: i32, col: u32) void {
    dl.addLine(.{ .p1 = .{ fx(x1), fx(y1) }, .p2 = .{ fx(x2), fx(y2) }, .col = col, .thickness = 1.5 });
}

pub fn cornerBrackets(dl: DrawList, r: Rect, n: i32, col: u32) void {
    line(dl, r.x, r.y, r.x + n, r.y, col);
    line(dl, r.x, r.y, r.x, r.y + n, col);
    line(dl, r.right(), r.y, r.right() - n, r.y, col);
    line(dl, r.right(), r.y, r.right(), r.y + n, col);
    line(dl, r.x, r.bottom(), r.x + n, r.bottom(), col);
    line(dl, r.x, r.bottom(), r.x, r.bottom() - n, col);
    line(dl, r.right(), r.bottom(), r.right() - n, r.bottom(), col);
    line(dl, r.right(), r.bottom(), r.right(), r.bottom() - n, col);
}

pub fn bar(dl: DrawList, r: Rect, frac: f32, fill_col: u32, track_col: u32) void {
    fillRect(dl, r, track_col);
    const w: i32 = @intFromFloat(@round(fx(r.w) * std.math.clamp(frac, 0.0, 1.0)));
    if (w > 0) fillRect(dl, .{ .x = r.x, .y = r.y, .w = w, .h = r.h }, fill_col);
}

pub fn text(dl: DrawList, x: i32, y: i32, col: u32, comptime fmt: []const u8, args: anytype) void {
    dl.addText(.{ fx(x), fx(y) }, col, fmt, args);
}

pub fn textAt(dl: DrawList, x: i32, y: i32, col: u32, txt: []const u8) void {
    dl.addTextUnformatted(.{ fx(x), fx(y) }, col, txt);
}

pub fn glyph(dl: DrawList, x: i32, y: i32, col: u32, ch: []const u8, size: f32) void {
    dl.addTextExtendedUnformatted(.{ fx(x), fx(y) }, col, ch, .{ .font = null, .font_size = size });
}

pub fn glyphGlow(dl: DrawList, x: i32, y: i32, col: u32, ch: []const u8, size: f32, radius: i32) void {
    const halo = theme.withAlpha(col, 0x40);
    const offs = [_][2]i32{ .{ radius, 0 }, .{ -radius, 0 }, .{ 0, radius }, .{ 0, -radius } };
    for (offs) |o| glyph(dl, x + o[0], y + o[1], halo, ch, size);
    glyph(dl, x, y, col, ch, size);
}

pub fn scanlines(dl: DrawList, r: Rect, alpha: u8) void {
    const col = theme.withAlpha(0x000000, alpha);
    var y = r.y;
    while (y < r.bottom()) : (y += 2) {
        dl.addLine(.{ .p1 = .{ fx(r.x), fx(y) }, .p2 = .{ fx(r.right()), fx(y) }, .col = col, .thickness = 1.0 });
    }
}

pub fn vignette(dl: DrawList, r: Rect, tint: u32, intensity: u8) void {
    const edge = theme.withAlpha(tint, intensity);
    const clear = theme.withAlpha(tint, 0);
    const band: i32 = @divFloor(r.h, 5);
    dl.addRectFilledMultiColor(.{
        .pmin = .{ fx(r.x), fx(r.y) },
        .pmax = .{ fx(r.right()), fx(r.y + band) },
        .col_upr_left = edge,
        .col_upr_right = edge,
        .col_bot_right = clear,
        .col_bot_left = clear,
    });
    dl.addRectFilledMultiColor(.{
        .pmin = .{ fx(r.x), fx(r.bottom() - band) },
        .pmax = .{ fx(r.right()), fx(r.bottom()) },
        .col_upr_left = clear,
        .col_upr_right = clear,
        .col_bot_right = edge,
        .col_bot_left = edge,
    });
}
