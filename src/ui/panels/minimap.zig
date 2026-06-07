const config = @import("../../config.zig");
const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");

pub fn draw_minimap(dl: draw.DrawList, run: *const RunState, area: layout.Rect, scale: f32) void {
    draw.panel(dl, area, .{});
    draw.textAt(dl, area.x + draw.so(10, scale), area.y + draw.so(8, scale), theme.palette.dim, "MAP");

    const cell = draw.so(2, scale);
    const map_px_w = @as(i32, config.map_width) * cell;
    const origin_x = area.x + @divFloor(area.w - map_px_w, 2);
    const origin_y = area.y + draw.so(22, scale);

    var y: i32 = 0;
    while (y < config.map_height) : (y += 1) {
        var x: i32 = 0;
        while (x < config.map_width) : (x += 1) {
            if (!run.visibility.isExplored(x, y)) continue;
            const tile = run.map.get(@intCast(x), @intCast(y));
            const visible = run.visibility.isVisible(x, y);
            const col: u32 = if (visible) switch (tile.kind) {
                .wall => theme.palette.dim,
                .floor => 0xFF2A4A3A,
                .door => 0xFF3A6A5A,
            } else switch (tile.kind) {
                .wall => 0xFF1A2020,
                .floor => 0xFF141E1A,
                .door => 0xFF1A2E28,
            };
            draw.fillRect(dl, .{
                .x = origin_x + x * cell,
                .y = origin_y + y * cell,
                .w = cell,
                .h = cell,
            }, col);
        }
    }

    // Visible enemies — red dots
    for (run.actors.enemies[0..run.actors.enemy_count]) |e| {
        if (!e.alive) continue;
        if (!run.visibility.isVisible(e.position.x, e.position.y)) continue;
        draw.fillRect(dl, .{
            .x = origin_x + e.position.x * cell,
            .y = origin_y + e.position.y * cell,
            .w = cell,
            .h = cell,
        }, 0xFF0055FF);
    }

    // Player — white dot
    draw.fillRect(dl, .{
        .x = origin_x + run.player.position.x * cell,
        .y = origin_y + run.player.position.y * cell,
        .w = cell,
        .h = cell,
    }, 0xFFFFFFFF);
}
