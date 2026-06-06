const zgui = @import("zgui");
const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");
const item_def = @import("../../items/item_def.zig");

pub fn draw_inventory(run: *const RunState, l: layout.Layout, sel: usize) void {
    const dl = zgui.getBackgroundDrawList();
    draw.fillRect(dl, .{ .x = 0, .y = 0, .w = l.window_width, .h = l.window_height }, theme.withAlpha(0x000000, 0xB0));
    const w: i32 = 420;
    const h: i32 = 460;
    const r = layout.Rect{ .x = @divFloor(l.window_width - w, 2), .y = @divFloor(l.window_height - h, 2), .w = w, .h = h };
    draw.panel(dl, r, .{ .fill = theme.palette.panel, .border = theme.palette.bright, .bracket_col = theme.palette.bright });
    draw.textAt(dl, r.x + 16, r.y + 14, theme.palette.bright, "INVENTORY");

    const inv = &run.player.inventory;
    var y = r.y + 44;
    var row: usize = 0;
    for (inv.items) |slot| {
        const item_id = slot orelse continue;
        const inst = run.items.getItem(item_id) orelse continue;
        const def = item_def.getById(inst.def_id) orelse continue;
        const equipped = inv.equipment.isEquipped(item_id);
        const col: u32 = if (row == sel) theme.palette.bright else if (equipped) 0xFF66FF33 else theme.palette.text;
        if (row == sel) draw.textAt(dl, r.x + 16, y, theme.palette.bright, ">");
        const tag = if (equipped) " [E]" else "";
        draw.text(dl, r.x + 34, y, col, "[{c}] {s}{s}", .{ def.glyph, def.name, tag });
        y += 20;
        row += 1;
    }
    draw.textAt(dl, r.x + 16, r.bottom() - 28, theme.palette.dim, "[J/K] select  [I/Esc] close");
}
