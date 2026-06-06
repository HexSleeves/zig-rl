const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");

pub fn draw_header(dl: draw.DrawList, run: *const RunState, l: layout.Layout) void {
    const s = l.scale;
    const tint = theme.alertTint(run.alert_level);
    draw.panel(dl, l.header, .{ .bracket_col = tint, .border = tint });
    const r = l.header;
    draw.text(dl, r.x + draw.so(12, s), r.y + draw.so(12, s), theme.palette.bright, "FACILITY // FLOOR {d}", .{run.current_floor});
    draw.text(dl, r.x + draw.so(280, s), r.y + draw.so(12, s), theme.palette.dim, "TURN {d}", .{run.turn_count});
    const meter_w = draw.so(160, s);
    const meter = layout.Rect{ .x = r.right() - meter_w - draw.so(110, s), .y = r.y + draw.so(15, s), .w = meter_w, .h = draw.so(10, s) };
    const frac: f32 = @as(f32, @floatFromInt(run.alert_level)) / 100.0;
    draw.bar(dl, meter, frac, tint, theme.palette.panel);
    const label = switch (theme.alertState(run.alert_level)) {
        .nominal => "NOMINAL",
        .caution => "CAUTION",
        .elevated => "ELEVATED",
        .alert => "ALERT",
        .lockdown => "LOCKDOWN",
    };
    draw.textAt(dl, meter.right() + draw.so(10, s), r.y + draw.so(12, s), tint, label);
}
