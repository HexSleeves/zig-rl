const zgui = @import("zgui");
const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");

pub fn draw_game_over(run: *const RunState, l: layout.Layout) void {
    const dl = zgui.getBackgroundDrawList();
    draw.fillRect(dl, .{ .x = 0, .y = 0, .w = l.window_width, .h = l.window_height }, theme.withAlpha(0x000000, 0xD0));
    const cx = @divFloor(l.window_width, 2);
    draw.glyph(dl, cx - 130, @divFloor(l.window_height, 3), 0xFF303BFF, "OPERATIVE LOST", 36.0);
    draw.text(dl, cx - 80, @divFloor(l.window_height, 2), theme.palette.text, "FLOOR {d}", .{run.current_floor});
    draw.text(dl, cx - 80, @divFloor(l.window_height, 2) + 22, theme.palette.text, "TURNS {d}", .{run.turn_count});
    draw.text(dl, cx - 80, @divFloor(l.window_height, 2) + 44, theme.palette.text, "KILLS {d}", .{run.kills});
    draw.textAt(dl, cx - 80, @divFloor(l.window_height, 2) + 90, theme.palette.dim, "[ENTER] MENU   [Q] QUIT");
}
