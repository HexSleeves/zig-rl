const std = @import("std");
const zglfw = @import("zglfw");
const zgui = @import("zgui");
const zopengl = @import("zopengl");

const Game = @import("game.zig").Game;
const config = @import("config.zig");
const input = @import("input.zig");
const actions = @import("actions.zig");
const item_def_mod = @import("items/item_def.zig");
const inventory_mod = @import("items/inventory.zig");
const ids = @import("ids.zig");
const layout = @import("ui/layout.zig");
const camera = @import("ui/camera.zig");
const theme = @import("ui/theme.zig");
const scene = @import("ui/scene.zig");
const inspect = @import("ui/panels/inspect.zig");
const inventory_screen = @import("ui/screens/inventory.zig");
const main_menu = @import("ui/screens/main_menu.zig");
const game_over = @import("ui/screens/game_over.zig");

const gl = zopengl.bindings;
const base_font_size: f32 = 14.0;

const InputState = struct {
    north: bool = false,
    south: bool = false,
    west: bool = false,
    east: bool = false,
    wait: bool = false,
    quit: bool = false,
    pickup: bool = false,
    hack: bool = false,
    f1: bool = false,
    enter: bool = false,
    inv: bool = false,
    esc: bool = false,
    inv_j: bool = false,
    inv_k: bool = false,
    inv_equip: bool = false,
    inv_use: bool = false,
    inv_drop: bool = false,
};

pub fn run(game: *Game, smoke_frame_limit: ?u32) !void {
    try zglfw.init();
    defer zglfw.terminate();

    zglfw.windowHint(.context_version_major, 3);
    zglfw.windowHint(.context_version_minor, 3);
    zglfw.windowHint(.opengl_profile, .opengl_core_profile);
    zglfw.windowHint(.opengl_forward_compat, true);
    zglfw.windowHint(.resizable, false);

    const base_layout = layout.layout();
    const window = try zglfw.Window.create(base_layout.window_width, base_layout.window_height, "zig-rl", null, null);
    defer window.destroy();

    zglfw.makeContextCurrent(window);
    zglfw.swapInterval(1);
    try zopengl.loadCoreProfile(zglfw.getProcAddress, 3, 3);

    zgui.init(std.heap.c_allocator);
    defer zgui.deinit();
    // Bundled monospace font. First font added becomes the default, so
    // pushFont(null,...) and draw-list text both use it. Must load before the
    // backend builds the font atlas. Path is relative to the run cwd (repo root).
    _ = zgui.io.addFontFromFile("assets/fonts/JetBrainsMono-Regular.ttf", 32.0);
    zgui.backend.init(window);
    defer zgui.backend.deinit();

    var in = InputState{};
    var frames: u32 = 0;
    var show_debug = false;
    var inv_sel: usize = 0;
    var fps: f32 = 0;
    var last_t: f64 = zglfw.getTime();
    var anim = scene.Anim{};
    var prev_alert: u8 = 0;

    while (!window.shouldClose() and !game.state.quit_requested) {
        zglfw.pollEvents();
        try handleInput(game, window, &in, &show_debug, &inv_sel);

        const fb = window.getFramebufferSize();
        gl.viewport(0, 0, fb[0], fb[1]);
        gl.clearColor(0.024, 0.039, 0.071, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        zgui.backend.newFrame(@intCast(fb[0]), @intCast(fb[1]));
        const l = layout.layoutForScale(framebufferScale(base_layout, fb));
        zgui.pushFont(null, base_font_size * l.scale);
        drawMode(game, window, l, show_debug, inv_sel, fps, anim);
        zgui.popFont();
        zgui.backend.draw();

        window.swapBuffers();
        const now = zglfw.getTime();
        const dt = now - last_t;
        if (dt > 0) fps = @floatCast(1.0 / dt);
        last_t = now;

        anim.time += @as(f32, @floatCast(dt));
        const real_alert: f32 = @floatFromInt(game.state.run.alert_level);
        anim.displayed_alert += (real_alert - anim.displayed_alert) * @as(f32, @floatCast(@min(dt * 4.0, 1.0)));
        if (game.state.run.alert_level > prev_alert) anim.glitch = 1.0;
        anim.glitch = @max(0.0, anim.glitch - @as(f32, @floatCast(dt * 2.0)));
        prev_alert = game.state.run.alert_level;

        frames += 1;
        if (smoke_frame_limit) |lim| if (frames >= lim) break;
    }
}

fn handleInput(game: *Game, window: *zglfw.Window, in: *InputState, show_debug: *bool, inv_sel: *usize) !void {
    if (pressedOne(window, &in.f1, .F1)) show_debug.* = !show_debug.*;
    switch (game.state.current_mode) {
        .main_menu => {
            if (pressedOne(window, &in.enter, .enter)) try game.state.startRun();
            if (pressedAny(window, &in.quit, &.{ .q, .escape })) game.state.quit_requested = true;
        },
        .running => {
            if (pressedOne(window, &in.inv, .i)) {
                game.state.current_mode = .inventory;
                inv_sel.* = 0;
                return;
            }
            if (readCommand(window, in)) |cmd| try game.handle(cmd);
        },
        .inventory => {
            if (pressedOne(window, &in.inv, .i) or pressedOne(window, &in.esc, .escape)) {
                game.state.current_mode = .running;
                return;
            }
            const rs = &game.state.run;
            const count = inventoryItemCount(rs);
            if (count > 0) {
                if (pressedOne(window, &in.inv_j, .j)) inv_sel.* = (inv_sel.* + 1) % count;
                if (pressedOne(window, &in.inv_k, .k)) inv_sel.* = if (inv_sel.* == 0) count - 1 else inv_sel.* - 1;
                if (pressedOne(window, &in.inv_equip, .e)) {
                    if (getSelectedItemId(rs, inv_sel.*)) |item_id| {
                        try toggleEquip(rs, item_id);
                    }
                }
                if (pressedOne(window, &in.inv_use, .u)) {
                    if (getSelectedItemId(rs, inv_sel.*)) |item_id| {
                        try actions.executeAction(.{ .use_item = item_id }, rs);
                        if (inv_sel.* > 0 and inv_sel.* >= inventoryItemCount(rs)) inv_sel.* -= 1;
                    }
                }
                if (pressedOne(window, &in.inv_drop, .d)) {
                    if (getSelectedItemId(rs, inv_sel.*)) |item_id| {
                        dropItem(rs, item_id);
                        if (inv_sel.* > 0 and inv_sel.* >= inventoryItemCount(rs)) inv_sel.* -= 1;
                    }
                }
            }
        },
        .game_over, .campaign_summary => {
            if (pressedOne(window, &in.enter, .enter)) game.state.current_mode = .main_menu;
            if (pressedAny(window, &in.quit, &.{ .q, .escape })) game.state.quit_requested = true;
        },
        else => {},
    }
}

fn inventoryItemCount(rs: *const @import("run_state.zig").RunState) usize {
    var count: usize = 0;
    for (rs.player.inventory.items) |slot| if (slot != null) { count += 1; };
    return count;
}

fn getSelectedItemId(rs: *const @import("run_state.zig").RunState, sel: usize) ?ids.ItemId {
    var row: usize = 0;
    for (rs.player.inventory.items) |slot| {
        const item_id = slot orelse continue;
        if (row == sel) return item_id;
        row += 1;
    }
    return null;
}

fn equipSlotForKind(kind: item_def_mod.ItemKind) ?inventory_mod.EquipSlot {
    return switch (kind) {
        .weapon => .primary_weapon,
        .armor => .armor_rig,
        .implant => .implant_1,
        .tool => .utility_1,
        else => null,
    };
}

fn toggleEquip(rs: *@import("run_state.zig").RunState, item_id: ids.ItemId) !void {
    const inst = rs.items.getItem(item_id) orelse return;
    const def = item_def_mod.getById(inst.def_id) orelse return;
    const slot = equipSlotForKind(def.kind) orelse {
        try rs.log.add("That item can't be equipped.");
        return;
    };
    if (rs.player.inventory.equipment.isEquipped(item_id)) {
        _ = rs.player.inventory.equipment.remove(slot);
        try rs.log.add("Unequipped.");
    } else {
        _ = rs.player.inventory.equip(item_id, slot);
        try rs.log.add("Equipped.");
    }
}

fn dropItem(rs: *@import("run_state.zig").RunState, item_id: ids.ItemId) void {
    for (&rs.player.inventory.equipment.slots) |*slot| {
        if (slot.*) |eid| if (eid.eql(item_id)) { slot.* = null; };
    }
    _ = rs.player.inventory.remove(item_id);
    if (rs.items.getItemMut(item_id)) |inst| {
        inst.owner = ids.ActorId.invalid;
        inst.x = rs.player.position.x;
        inst.y = rs.player.position.y;
    }
}

fn drawMode(game: *Game, window: *zglfw.Window, l: layout.Layout, show_debug: bool, inv_sel: usize, fps: f32, anim: scene.Anim) void {
    const rs = &game.state.run;
    switch (game.state.current_mode) {
        .main_menu => main_menu.draw_menu(l),
        .game_over, .campaign_summary => game_over.draw_game_over(rs, l),
        .running, .inventory => {
            const cam = camera.follow(rs.player.position.x, rs.player.position.y, @intCast(rs.map.width), @intCast(rs.map.height), l.viewport());
            const target = resolveTarget(rs, window, l, cam);
            scene.draw_scene(rs, l, cam, target, anim);
            if (game.state.current_mode == .inventory) inventory_screen.draw_inventory(rs, l, inv_sel);
        },
        else => {},
    }
    if (show_debug) drawDebug(game, fps);
}

fn resolveTarget(rs: anytype, window: *zglfw.Window, l: layout.Layout, cam: camera.Camera) inspect.Target {
    const cursor = window.getCursorPos();
    const mx: i32 = @intFromFloat(cursor[0]);
    const my: i32 = @intFromFloat(cursor[1]);
    if (camera.screenToTile(mx, my, cam, l.viewport())) |t| {
        if (rs.visibility.isVisible(t[0], t[1])) {
            for (rs.actors.enemiesSlice(), 0..) |e, i| {
                if (e.alive and e.position.x == t[0] and e.position.y == t[1]) return .{ .enemy_index = i };
            }
            for (rs.items.instances[0..rs.items.count], 0..) |inst, i| {
                if (inst.x == t[0] and inst.y == t[1]) return .{ .item_index = i };
            }
            return .{ .tile = t };
        }
    }
    var best: ?usize = null;
    var best_d: i32 = 1 << 30;
    for (rs.actors.enemiesSlice(), 0..) |e, i| {
        if (!e.alive or !rs.visibility.isVisible(e.position.x, e.position.y)) continue;
        const dx: i32 = @intCast(@abs(e.position.x - rs.player.position.x));
        const dy: i32 = @intCast(@abs(e.position.y - rs.player.position.y));
        const d = @max(dx, dy);
        if (d < best_d) {
            best_d = d;
            best = i;
        }
    }
    if (best) |i| return .{ .enemy_index = i };
    return .none;
}

fn readCommand(window: *zglfw.Window, state: *InputState) ?input.Command {
    if (pressedAny(window, &state.north, &.{ .w, .k, .up })) return .{ .move = .north };
    if (pressedAny(window, &state.south, &.{ .s, .j, .down })) return .{ .move = .south };
    if (pressedAny(window, &state.west, &.{ .a, .left })) return .{ .move = .west };
    if (pressedAny(window, &state.east, &.{ .d, .l, .right })) return .{ .move = .east };
    if (pressedAny(window, &state.wait, &.{ .period, .space })) return .wait;
    if (pressedAny(window, &state.quit, &.{ .q, .escape })) return .quit;
    if (pressedAny(window, &state.pickup, &.{.g})) return .pickup;
    if (pressedAny(window, &state.hack, &.{.h})) return .hack;
    return null;
}

fn pressedAny(window: *zglfw.Window, previous: *bool, keys: []const zglfw.Key) bool {
    var current = false;
    for (keys) |key| {
        const action = window.getKey(key);
        current = current or action == .press or action == .repeat;
    }
    defer previous.* = current;
    return current and !previous.*;
}

fn pressedOne(window: *zglfw.Window, previous: *bool, key: zglfw.Key) bool {
    const action = window.getKey(key);
    const current = action == .press or action == .repeat;
    defer previous.* = current;
    return current and !previous.*;
}

fn framebufferScale(base_layout: layout.Layout, fb_size: [2]c_int) f32 {
    const x = @as(f32, @floatFromInt(fb_size[0])) / @as(f32, @floatFromInt(base_layout.window_width));
    const y = @as(f32, @floatFromInt(fb_size[1])) / @as(f32, @floatFromInt(base_layout.window_height));
    return @max(1.0, @min(x, y));
}

fn drawDebug(game: *const Game, fps: f32) void {
    const rs = &game.state.run;
    if (zgui.begin("Debug", .{ .flags = .{ .no_saved_settings = true } })) {
        zgui.text("Seed:  {d}", .{rs.run_seed});
        zgui.text("Floor: {d}", .{rs.current_floor});
        zgui.text("Turn:  {d}", .{rs.turn_count});
        zgui.text("Mode:  {s}", .{@tagName(game.state.current_mode)});
        zgui.text("FPS:   {d:.1}", .{fps});
        zgui.text("Alert: {d}", .{rs.alert_level});
    }
    zgui.end();
}
