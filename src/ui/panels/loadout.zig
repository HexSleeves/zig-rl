const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");
const item_def = @import("../../items/item_def.zig");

pub fn draw_loadout(dl: draw.DrawList, run: *const RunState, area: layout.Rect, scale: f32) void {
    draw.panel(dl, area, .{});
    const x = area.x + draw.so(10, scale);
    draw.textAt(dl, x, area.y + draw.so(8, scale), theme.palette.dim, "LOADOUT");
    const inv = &run.player.inventory;
    var line_y = area.y + draw.so(28, scale);
    const step = draw.so(18, scale);
    var shown: usize = 0;
    for (inv.equipment.slots) |maybe_eid| {
        const eid = maybe_eid orelse continue;
        const inst = run.items.getItem(eid) orelse continue;
        const def = item_def.getById(inst.def_id) orelse continue;
        draw.text(dl, x, line_y, theme.palette.bright, "[{c}] {s}", .{ def.glyph, def.name });
        line_y += step;
        shown += 1;
    }
    if (shown == 0) draw.textAt(dl, x, line_y, theme.palette.dim, "(nothing equipped)");
    draw.text(dl, x, area.bottom() - draw.so(24, scale), theme.palette.dim, "+{d} carried", .{inv.count});
}
