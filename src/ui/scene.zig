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
const inspect = @import("panels/inspect.zig");
const log_panel = @import("panels/log_panel.zig");

pub fn draw_scene(run: *const RunState, l: layout.Layout, cam: camera.Camera, target: inspect.Target) void {
    const dl = zgui.getBackgroundDrawList();

    draw.fillRect(dl, .{ .x = 0, .y = 0, .w = l.window_width, .h = l.window_height }, theme.palette.background);

    map_view.draw_view(dl, run, l, cam);
    const tint = theme.alertTint(run.alert_level);
    draw.panel(dl, l.map, .{ .fill = null, .border = tint, .bracket_col = tint });

    const vitals_h: i32 = 84;
    vitals.draw_vitals(dl, run, .{ .x = l.sidebar.x, .y = l.sidebar.y, .w = l.sidebar.w, .h = vitals_h });
    loadout.draw_loadout(dl, run, .{ .x = l.sidebar.x, .y = l.sidebar.y + vitals_h + 8, .w = l.sidebar.w, .h = l.sidebar.h - vitals_h - 8 });

    header.draw_header(dl, run, l);
    inspect.draw_inspect(dl, run, l.inspect, target);
    log_panel.draw_log(dl, run, l.log);

    draw.scanlines(dl, l.map, 0x18);
    const state = theme.alertState(run.alert_level);
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
    if (state == .lockdown) {
        const banner = layout.Rect{ .x = l.map.x + @divFloor(l.map.w, 2) - 160, .y = l.map.y + 8, .w = 320, .h = 26 };
        draw.panel(dl, banner, .{ .fill = theme.withAlpha(0xFF2010C8, 0xC0), .border = 0xFF2010C8, .brackets = true });
        draw.textAt(dl, banner.x + 18, banner.y + 7, 0xFFFFFFFF, "FACILITY LOCKDOWN - SECTOR SEALED");
    }
}
