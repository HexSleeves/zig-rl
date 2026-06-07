const std = @import("std");
const zgui = @import("zgui");
const RunState = @import("../../run_state.zig").RunState;
const camera = @import("../camera.zig");
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");
const item_def = @import("../../items/item_def.zig");

const actor_font_base: f32 = 16.0;

pub fn draw_view(dl: draw.DrawList, run: *const RunState, l: layout.Layout, cam: camera.Camera) void {
    const vp = l.viewport();
    const font = actor_font_base * l.scale;
    const gx = draw.so(4, l.scale);
    const gy = draw.so(2, l.scale);
    const inset = draw.so(4, l.scale);
    draw.fillRect(dl, l.map, theme.palette.map_void);

    var ly: i32 = 0;
    while (ly < vp.tiles_h) : (ly += 1) {
        var lx: i32 = 0;
        while (lx < vp.tiles_w) : (lx += 1) {
            const wx = cam.tile_x + lx;
            const wy = cam.tile_y + ly;
            if (wx < 0 or wy < 0 or wx >= @as(i32, @intCast(run.map.width)) or wy >= @as(i32, @intCast(run.map.height))) continue;
            const px = vp.origin_x + lx * vp.tile_size;
            const py = vp.origin_y + ly * vp.tile_size;
            const visible = run.visibility.isVisible(wx, wy);
            const explored = run.visibility.isExplored(wx, wy);
            if (!visible and !explored) continue;
            const kind = run.map.get(@intCast(wx), @intCast(wy)).kind;
            var col: u32 = switch (kind) {
                .wall => theme.palette.wall,
                .floor => theme.palette.dim,
                .door => theme.palette.accent,
            };
            if (!visible) col = theme.darken(col, 0.35);
            draw.fillRect(dl, .{ .x = px, .y = py, .w = vp.tile_size, .h = vp.tile_size }, col);

            if (visible) {
                if (run.objects.objectAt(@intCast(wx), @intCast(wy))) |oid| {
                    if (run.objects.getObject(oid)) |obj| {
                        const oc: ?u32 = switch (obj.kind) {
                            .terminal => theme.palette.accent,
                            .camera => if (obj.powered) theme.alertTint(run.alert_level) else theme.palette.dim,
                            .locker => theme.palette.bright,
                            else => null,
                        };
                        if (oc) |c| draw.fillRect(dl, .{ .x = px + inset, .y = py + inset, .w = vp.tile_size - inset * 2, .h = vp.tile_size - inset * 2 }, c);
                    }
                }
            }
        }
    }

    for (run.items.instances[0..run.items.count]) |*inst| {
        if (inst.x < 0) continue;
        if (!run.visibility.isVisible(inst.x, inst.y)) continue;
        if (!inViewport(inst.x, inst.y, cam, vp)) continue;
        const def = item_def.getById(inst.def_id) orelse continue;
        const sp = camera.tileToScreen(inst.x, inst.y, cam, vp);
        draw.glyph(dl, sp[0] + gx, sp[1] + gy, 0xFF66FF33, &[_]u8{def.glyph}, font);
    }

    for (run.actors.enemiesSlice()) |enemy| {
        if (!enemy.alive) continue;
        if (!run.visibility.isVisible(enemy.position.x, enemy.position.y)) continue;
        if (!inViewport(enemy.position.x, enemy.position.y, cam, vp)) continue;
        const sp = camera.tileToScreen(enemy.position.x, enemy.position.y, cam, vp);
        const aware = enemy.ai.mode == .chase or enemy.ai.mode == .flee;
        const threat: u32 = if (aware) 0xFF303BFF else 0xFF1E8AFF; // red aware / orange idle
        draw.glyph(dl, sp[0] + gx, sp[1] + gy, threat, &[_]u8{enemy.glyph}, font);
    }

    const psp = camera.tileToScreen(run.player.position.x, run.player.position.y, cam, vp);
    draw.glyphGlow(dl, psp[0] + gx, psp[1] + gy, theme.palette.bright, "@", font, draw.so(1, l.scale));
}

fn inViewport(wx: i32, wy: i32, cam: camera.Camera, vp: camera.Viewport) bool {
    return wx >= cam.tile_x and wy >= cam.tile_y and
        wx < cam.tile_x + vp.tiles_w and wy < cam.tile_y + vp.tiles_h;
}
