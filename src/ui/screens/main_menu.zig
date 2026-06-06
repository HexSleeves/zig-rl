const zgui = @import("zgui");
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");

pub fn draw_menu(l: layout.Layout) void {
    const dl = zgui.getBackgroundDrawList();
    draw.fillRect(dl, .{ .x = 0, .y = 0, .w = l.window_width, .h = l.window_height }, theme.palette.background);
    const cx = @divFloor(l.window_width, 2);
    draw.glyph(dl, cx - 120, @divFloor(l.window_height, 3), theme.palette.bright, "ZIG-RL", 48.0);
    draw.textAt(dl, cx - 130, @divFloor(l.window_height, 3) + 70, theme.palette.dim, "// SCI-FI FACILITY ROGUELITE");
    draw.textAt(dl, cx - 70, @divFloor(l.window_height, 2) + 30, theme.palette.text, "[ENTER]  NEW RUN");
    draw.textAt(dl, cx - 70, @divFloor(l.window_height, 2) + 60, theme.palette.text, "[Q]      QUIT");
}
