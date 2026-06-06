const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");

pub fn draw_header(dl: draw.DrawList, run: *const RunState, l: layout.Layout) void {
    const tint = theme.alertTint(run.alert_level);
    draw.panel(dl, l.header, .{ .bracket_col = tint, .border = tint });
    const r = l.header;
    draw.text(dl, r.x + 10, r.y + 12, theme.palette.bright, "FACILITY // FLOOR {d}", .{run.current_floor});
    draw.text(dl, r.x + 220, r.y + 12, theme.palette.dim, "TURN {d}", .{run.turn_count});
    const meter_w: i32 = 160;
    const meter = layout.Rect{ .x = r.right() - meter_w - 90, .y = r.y + 14, .w = meter_w, .h = 10 };
    const frac: f32 = @as(f32, @floatFromInt(run.alert_level)) / 100.0;
    draw.bar(dl, meter, frac, tint, theme.palette.panel);
    const label = switch (theme.alertState(run.alert_level)) {
        .nominal => "NOMINAL",
        .caution => "CAUTION",
        .elevated => "ELEVATED",
        .alert => "ALERT",
        .lockdown => "LOCKDOWN",
    };
    draw.textAt(dl, meter.right() + 8, r.y + 12, tint, label);
}
