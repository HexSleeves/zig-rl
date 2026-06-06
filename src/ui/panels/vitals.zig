const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");

pub fn draw_vitals(dl: draw.DrawList, run: *const RunState, area: layout.Rect) void {
    draw.panel(dl, area, .{});
    const p = run.player;
    draw.textAt(dl, area.x + 10, area.y + 8, theme.palette.dim, "VITALS");
    draw.text(dl, area.x + 10, area.y + 26, theme.palette.text, "HP {d}/{d}", .{ p.hp, p.max_hp });
    const frac: f32 = if (p.max_hp > 0) @as(f32, @floatFromInt(p.hp)) / @as(f32, @floatFromInt(p.max_hp)) else 0;
    const hp_col: u32 = if (frac > 0.5) 0xFF66FF33 else if (frac > 0.25) 0xFF00CCFF else 0xFF303BFF;
    draw.bar(dl, .{ .x = area.x + 10, .y = area.y + 44, .w = area.w - 20, .h = 8 }, frac, hp_col, theme.palette.panel);
    draw.text(dl, area.x + 10, area.y + 58, theme.palette.text, "ARM {d}  EVA {d}", .{ p.armor, p.evasion });
}
