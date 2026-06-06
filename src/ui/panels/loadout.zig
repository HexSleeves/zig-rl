const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");
const item_def = @import("../../items/item_def.zig");

pub fn draw_loadout(dl: draw.DrawList, run: *const RunState, area: layout.Rect) void {
    draw.panel(dl, area, .{});
    draw.textAt(dl, area.x + 10, area.y + 8, theme.palette.dim, "LOADOUT");
    const inv = &run.player.inventory;
    var line_y = area.y + 26;
    var shown: usize = 0;
    for (inv.equipment.slots) |maybe_eid| {
        const eid = maybe_eid orelse continue;
        const inst = run.items.getItem(eid) orelse continue;
        const def = item_def.getById(inst.def_id) orelse continue;
        draw.text(dl, area.x + 10, line_y, theme.palette.bright, "[{c}] {s}", .{ def.glyph, def.name });
        line_y += 16;
        shown += 1;
    }
    if (shown == 0) draw.textAt(dl, area.x + 10, line_y, theme.palette.dim, "(nothing equipped)");
    draw.text(dl, area.x + 10, area.bottom() - 22, theme.palette.dim, "+{d} carried", .{inv.count});
}
