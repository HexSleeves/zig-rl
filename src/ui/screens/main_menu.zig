const zgui = @import("zgui");
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");

pub fn draw_menu(l: layout.Layout) void {
    const s = l.scale;
    const dl = zgui.getBackgroundDrawList();
    draw.fillRect(dl, .{ .x = 0, .y = 0, .w = l.window_width, .h = l.window_height }, theme.palette.background);
    const cx = @divFloor(l.window_width, 2);
    const top = @divFloor(l.window_height, 3);
    const mid = @divFloor(l.window_height, 2);
    draw.glyph(dl, cx - draw.so(120, s), top, theme.palette.bright, "ZIG-RL", 48.0 * s);
    draw.textAt(dl, cx - draw.so(140, s), top + draw.so(72, s), theme.palette.dim, "// SCI-FI FACILITY ROGUELITE");
    draw.textAt(dl, cx - draw.so(80, s), mid + draw.so(30, s), theme.palette.text, "[ENTER]  NEW RUN");
    draw.textAt(dl, cx - draw.so(80, s), mid + draw.so(58, s), theme.palette.text, "[Q]      QUIT");
}
