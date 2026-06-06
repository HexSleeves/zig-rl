const std = @import("std");
const RunState = @import("../../run_state.zig").RunState;
const layout = @import("../layout.zig");
const theme = @import("../theme.zig");
const draw = @import("../draw.zig");

fn severityColor(line: []const u8) u32 {
    if (containsAny(line, &.{ "hit", "damage", "kill", "dies", "acquires", "attack" })) return 0xFF303BFF;
    if (containsAny(line, &.{ "hacked", "picked", "found", "open" })) return 0xFF66FF33;
    if (containsAny(line, &.{ "Alert", "alert", "Camera", "Lockdown", "spotted" })) return 0xFF00CCFF;
    return theme.palette.dim;
}

fn containsAny(haystack: []const u8, needles: []const []const u8) bool {
    for (needles) |n| {
        if (std.mem.indexOf(u8, haystack, n) != null) return true;
    }
    return false;
}

pub fn draw_log(dl: draw.DrawList, run: *const RunState, area: layout.Rect, scale: f32) void {
    draw.panel(dl, area, .{});
    const x = area.x + draw.so(10, scale);
    draw.textAt(dl, x, area.y + draw.so(8, scale), theme.palette.dim, "SYSTEM LOG");
    const n = run.log.count();
    var i: usize = 0;
    var y = area.y + draw.so(28, scale);
    const step = draw.so(18, scale);
    while (i < n) : (i += 1) {
        const linetxt = run.log.at(i);
        draw.text(dl, x, y, severityColor(linetxt), "> {s}", .{linetxt});
        y += step;
    }
    draw.textAt(dl, x, area.bottom() - draw.so(20, scale), theme.palette.dim, "[WASD] move  [H] hack  [G] grab  [I] inventory  [.] wait  [Q] quit");
}
