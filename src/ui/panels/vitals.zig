const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");

pub fn draw_vitals(dl: draw.DrawList, run: *const RunState, area: layout.Rect, scale: f32) void {
    draw.panel(dl, area, .{});
    const p = run.player;
    const x = area.x + draw.so(10, scale);
    draw.textAt(dl, x, area.y + draw.so(8, scale), theme.palette.dim, "VITALS");
    draw.text(dl, x, area.y + draw.so(26, scale), theme.palette.text, "HP {d}/{d}", .{ p.hp, p.max_hp });
    const frac: f32 = if (p.max_hp > 0) @as(f32, @floatFromInt(p.hp)) / @as(f32, @floatFromInt(p.max_hp)) else 0;
    const hp_col: u32 = if (frac > 0.5) 0xFF66FF33 else if (frac > 0.25) 0xFF00CCFF else 0xFF303BFF;
    draw.bar(dl, .{ .x = x, .y = area.y + draw.so(46, scale), .w = area.w - draw.so(20, scale), .h = draw.so(8, scale) }, frac, hp_col, theme.palette.panel);
    draw.text(dl, x, area.y + draw.so(60, scale), theme.palette.text, "ARM {d}  EVA {d}", .{ p.armor, p.evasion });
}
