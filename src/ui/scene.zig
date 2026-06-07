const zgui = @import("zgui");
const RunState = @import("../run_state.zig").RunState;
const layout = @import("layout.zig");
const camera = @import("camera.zig");
const theme = @import("theme.zig");
const draw = @import("draw.zig");
const map_view = @import("panels/map_view.zig");
const header = @import("panels/header.zig");
const vitals = @import("panels/vitals.zig");
const loadout = @import("panels/loadout.zig");
const minimap = @import("panels/minimap.zig");
const inspect = @import("panels/inspect.zig");
const log_panel = @import("panels/log_panel.zig");

pub const Anim = struct {
    time: f32 = 0,
    displayed_alert: f32 = 0,
    glitch: f32 = 0,
};

pub fn draw_scene(run: *const RunState, l: layout.Layout, cam: camera.Camera, target: inspect.Target, anim: Anim) void {
    const dl = zgui.getBackgroundDrawList();

    draw.fillRect(dl, .{ .x = 0, .y = 0, .w = l.window_width, .h = l.window_height }, theme.palette.background);

    map_view.draw_view(dl, run, l, cam);
    const disp: u8 = @intFromFloat(@max(0.0, @min(100.0, anim.displayed_alert)));
    const tint = theme.alertTint(disp);
    const state = theme.alertState(disp);
    draw.panel(dl, l.map, .{ .fill = null, .border = tint, .bracket_col = tint });

    const vitals_h = draw.so(84, l.scale);
    const split_gap = draw.so(8, l.scale);
    const minimap_h = draw.so(82, l.scale);
    const loadout_h = l.sidebar.h - vitals_h - split_gap - minimap_h - split_gap;
    vitals.draw_vitals(dl, run, .{ .x = l.sidebar.x, .y = l.sidebar.y, .w = l.sidebar.w, .h = vitals_h }, l.scale);
    loadout.draw_loadout(dl, run, .{ .x = l.sidebar.x, .y = l.sidebar.y + vitals_h + split_gap, .w = l.sidebar.w, .h = loadout_h }, l.scale);
    minimap.draw_minimap(dl, run, .{ .x = l.sidebar.x, .y = l.sidebar.bottom() - minimap_h, .w = l.sidebar.w, .h = minimap_h }, l.scale);

    header.draw_header(dl, run, l);
    inspect.draw_inspect(dl, run, l.inspect, target, l.scale);
    log_panel.draw_log(dl, run, l.log, l.scale);

    draw.scanlines(dl, l.map, 0x18);
    if (state != .nominal) {
        const vintensity: u8 = switch (state) {
            .caution => 0x20,
            .elevated => 0x40,
            .alert => 0x70,
            .lockdown => 0xA0,
            .nominal => 0,
        };
        draw.vignette(dl, l.map, tint, vintensity);
    }
    if (anim.glitch > 0) {
        const shift: i32 = @intFromFloat(anim.glitch * 6.0 * l.scale);
        const band = layout.Rect{ .x = l.map.x + shift, .y = l.map.y + @divFloor(l.map.h, 3), .w = l.map.w, .h = draw.so(6, l.scale) };
        draw.fillRect(dl, band, theme.withAlpha(tint, 0x50));
    }
    if (state == .lockdown) {
        const pulse: u8 = @intFromFloat(160.0 + 60.0 * @sin(anim.time * 6.0));
        const bw = draw.so(320, l.scale);
        const banner = layout.Rect{ .x = l.map.x + @divFloor(l.map.w - bw, 2), .y = l.map.y + draw.so(8, l.scale), .w = bw, .h = draw.so(26, l.scale) };
        draw.panel(dl, banner, .{ .fill = theme.withAlpha(0xFF2010C8, pulse), .border = 0xFF2010C8, .brackets = true });
        draw.textAt(dl, banner.x + draw.so(18, l.scale), banner.y + draw.so(7, l.scale), 0xFFFFFFFF, "FACILITY LOCKDOWN - SECTOR SEALED");
    }
}
