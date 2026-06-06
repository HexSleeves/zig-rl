const zgui = @import("zgui");
const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");

pub fn draw_game_over(run: *const RunState, l: layout.Layout) void {
    const s = l.scale;
    const dl = zgui.getBackgroundDrawList();
    draw.fillRect(dl, .{ .x = 0, .y = 0, .w = l.window_width, .h = l.window_height }, theme.withAlpha(0x000000, 0xD0));
    const cx = @divFloor(l.window_width, 2);
    const mid = @divFloor(l.window_height, 2);
    draw.glyph(dl, cx - draw.so(150, s), @divFloor(l.window_height, 3), 0xFF303BFF, "OPERATIVE LOST", 36.0 * s);
    draw.text(dl, cx - draw.so(80, s), mid, theme.palette.text, "FLOOR {d}", .{run.current_floor});
    draw.text(dl, cx - draw.so(80, s), mid + draw.so(24, s), theme.palette.text, "TURNS {d}", .{run.turn_count});
    draw.text(dl, cx - draw.so(80, s), mid + draw.so(48, s), theme.palette.text, "KILLS {d}", .{run.kills});
    draw.textAt(dl, cx - draw.so(80, s), mid + draw.so(96, s), theme.palette.dim, "[ENTER] MENU   [Q] QUIT");
}
