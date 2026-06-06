const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");
const item_def = @import("../../items/item_def.zig");

/// What the inspect panel points at. Resolved by window.zig each frame.
pub const Target = union(enum) {
    none,
    enemy_index: usize,
    item_index: usize,
    tile: [2]i32,
};

pub fn draw_inspect(dl: draw.DrawList, run: *const RunState, area: layout.Rect, target: Target) void {
    draw.panel(dl, area, .{});
    draw.textAt(dl, area.x + 10, area.y + 8, theme.palette.dim, "INSPECT");
    switch (target) {
        .none => draw.textAt(dl, area.x + 10, area.y + 30, theme.palette.dim, "(hover the map)"),
        .enemy_index => |i| {
            const e = run.actors.enemiesSlice()[i];
            draw.textAt(dl, area.x + 10, area.y + 30, 0xFF303BFF, e.name);
            const frac: f32 = if (e.max_hp > 0) @as(f32, @floatFromInt(e.hp)) / @as(f32, @floatFromInt(e.max_hp)) else 0;
            draw.bar(dl, .{ .x = area.x + 10, .y = area.y + 48, .w = area.w - 20, .h = 8 }, frac, 0xFF303BFF, theme.palette.panel);
            draw.text(dl, area.x + 10, area.y + 62, theme.palette.text, "HP {d}/{d}", .{ e.hp, e.max_hp });
            draw.text(dl, area.x + 10, area.y + 80, theme.palette.text, "ARM {d}  EVA {d}", .{ e.armor, e.evasion });
        },
        .item_index => |i| {
            const inst = run.items.instances[i];
            if (item_def.getById(inst.def_id)) |def| {
                draw.textAt(dl, area.x + 10, area.y + 30, 0xFF66FF33, def.name);
            }
        },
        .tile => |t| draw.text(dl, area.x + 10, area.y + 30, theme.palette.text, "tile {d},{d}", .{ t[0], t[1] }),
    }
}
