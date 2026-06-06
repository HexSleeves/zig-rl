const std = @import("std");
const zglfw = @import("zglfw");
const zgui = @import("zgui");
const zopengl = @import("zopengl");

const Game = @import("game.zig").Game;
const config = @import("config.zig");
const input = @import("input.zig");
const render = @import("render.zig");
const procgen = @import("world/procgen.zig");
const item_def = @import("items/item_def.zig");
const inventory_mod = @import("items/inventory.zig");

const gl = zopengl.bindings;
const base_font_size: f32 = 13.0;
const actor_font_size: f32 = 16.0;

const Palette = struct {
    background: u32 = 0xff181412,
    panel: u32 = 0xff241f1c,
    wall: u32 = 0xff463d34,
    floor: u32 = 0xff27241f,
    grid: u32 = 0xff36302a,
    player: u32 = 0xff7acbed,
    enemy: u32 = 0xff5c54d1,
    text: u32 = 0xffe5e2dc,
    muted: u32 = 0xffa69f98,
};

const palette = Palette{};

const InputState = struct {
    north: bool = false,
    south: bool = false,
    west: bool = false,
    east: bool = false,
    wait: bool = false,
    quit: bool = false,
    pickup: bool = false,
    hack: bool = false,
    debug_toggle: bool = false,
};

pub fn run(game: *Game, smoke_frame_limit: ?u32) !void {
    try zglfw.init();
    defer zglfw.terminate();

    zglfw.windowHint(.context_version_major, 3);
    zglfw.windowHint(.context_version_minor, 3);
    zglfw.windowHint(.opengl_profile, .opengl_core_profile);
    zglfw.windowHint(.opengl_forward_compat, true);
    zglfw.windowHint(.resizable, false);

    const base_layout = render.layout();
    const window = try zglfw.Window.create(base_layout.window_width, base_layout.window_height, "zig-rl", null, null);
    defer window.destroy();

    zglfw.makeContextCurrent(window);
    zglfw.swapInterval(1);

    try zopengl.loadCoreProfile(zglfw.getProcAddress, 3, 3);

    zgui.init(std.heap.c_allocator);
    defer zgui.deinit();
    zgui.backend.init(window);
    defer zgui.backend.deinit();

    var input_state = InputState{};
    var frames_rendered: u32 = 0;
    var show_debug_panel: bool = true;
    var show_zone_overlay: bool = false;
    var show_inventory: bool = false;
    var last_frame_time: f64 = zglfw.getTime();
    var fps: f32 = 0.0;

    while (!window.shouldClose() and !game.state.quit_requested) {
        zglfw.pollEvents();
        if (readCommand(window, &input_state)) |command| {
            try game.handle(command);
        }
        if (pressedOne(window, &input_state.debug_toggle, .F1)) {
            show_debug_panel = !show_debug_panel;
        }
        if (pressedOne(window, &input_state.debug_toggle, .F2)) {
            show_zone_overlay = !show_zone_overlay;
        }
        if (pressedOne(window, &input_state.debug_toggle, .i)) {
            show_inventory = !show_inventory;
        }

        const fb_size = window.getFramebufferSize();
        gl.viewport(0, 0, fb_size[0], fb_size[1]);
        gl.clearColor(0.071, 0.078, 0.094, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        zgui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));
        const l = render.layoutForScale(framebufferScale(base_layout, fb_size));
        drawGame(game, l, show_debug_panel, show_zone_overlay, show_inventory, fps);
        zgui.backend.draw();

        window.swapBuffers();

        const now = zglfw.getTime();
        const dt = now - last_frame_time;
        if (dt > 0.0) fps = @floatCast(1.0 / dt);
        last_frame_time = now;

        frames_rendered += 1;
        if (smoke_frame_limit) |smoke_frames| {
            if (frames_rendered >= smoke_frames) break;
        }
    }
}

fn framebufferScale(base_layout: render.Layout, fb_size: [2]c_int) f32 {
    const x_scale = @as(f32, @floatFromInt(fb_size[0])) / @as(f32, @floatFromInt(base_layout.window_width));
    const y_scale = @as(f32, @floatFromInt(fb_size[1])) / @as(f32, @floatFromInt(base_layout.window_height));
    return @max(1.0, @min(x_scale, y_scale));
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

fn drawGame(game: *const Game, l: render.Layout, show_debug: bool, show_zones: bool, show_inventory: bool, fps: f32) void {
    zgui.pushFont(null, base_font_size * l.scale);
    defer zgui.popFont();

    drawMap(game, l);
    if (show_zones) drawZoneOverlay(game, l);
    drawHud(game, l);
    drawLog(game, l);
    if (show_debug) drawDebug(game, fps);
    if (show_inventory) drawInventory(game, fps);
}

fn drawHud(game: *const Game, l: render.Layout) void {
    zgui.setNextWindowPos(.{ .x = 0, .y = 0, .cond = .always });
    zgui.setNextWindowSize(.{ .w = @floatFromInt(l.window_width), .h = @floatFromInt(l.map_origin_y), .cond = .always });
    if (zgui.begin("HUD", .{ .flags = fixedPanelFlags() })) {
        zgui.text("zig-rl", .{});
        zgui.sameLine(.{});
        zgui.textDisabled("WASD move  . wait  G pick up  H hack  I inventory  Q quit", .{});
        zgui.sameLine(.{ .spacing = 32 });
        zgui.text("HP:{d}/{d}  Turn:{d}  Alert:{d}", .{ game.state.run.player.hp, game.state.run.player.max_hp, game.state.run.turn_count, game.state.run.alert_level });
        if (game.state.run.alert_level >= 80) {
            zgui.sameLine(.{});
            zgui.textColored(.{ 1.0, 0.2, 0.2, 1.0 }, "[LOCKDOWN]", .{});
        }
    }
    zgui.end();
}

fn dimColor(c: u32) u32 {
    const r = (c >> 0) & 0xff;
    const g = (c >> 8) & 0xff;
    const b = (c >> 16) & 0xff;
    const a = (c >> 24) & 0xff;
    return (a << 24) | ((b / 2) << 16) | ((g / 2) << 8) | (r / 2);
}

fn drawMap(game: *const Game, l: render.Layout) void {
    const draw_list = zgui.getBackgroundDrawList();
    draw_list.addRectFilled(.{
        .pmin = .{ 0, 0 },
        .pmax = .{ @floatFromInt(l.window_width), @floatFromInt(l.window_height) },
        .col = palette.background,
    });

    var y: usize = 0;
    while (y < game.state.run.map.height) : (y += 1) {
        var x: usize = 0;
        while (x < game.state.run.map.width) : (x += 1) {
            const px = l.map_origin_x + @as(i32, @intCast(x)) * l.tile_size;
            const py = l.map_origin_y + @as(i32, @intCast(y)) * l.tile_size;
            const is_visible = game.state.run.visibility.isVisible(@intCast(x), @intCast(y));
            const is_explored = game.state.run.visibility.isExplored(@intCast(x), @intCast(y));
            const tile_kind = game.state.run.map.get(x, y).kind;
            var color = if (is_visible) switch (tile_kind) {
                .wall => palette.wall,
                .floor => palette.floor,
                .door => 0xff_44_66_88,
            } else if (is_explored) switch (tile_kind) {
                .wall => dimColor(palette.wall),
                .floor => dimColor(palette.floor),
                .door => dimColor(0xff_44_66_88),
            } else palette.background;
            // Object overlay
            if (is_visible) {
                if (game.state.run.objects.objectAt(@intCast(x), @intCast(y))) |obj_id| {
                    if (game.state.run.objects.getObject(obj_id)) |obj| {
                        switch (obj.kind) {
                            .door => color = if (obj.state == .open) palette.floor else 0xff_44_66_88,
                            .terminal => color = 0xff_22_aa_44,
                            .camera => color = if (obj.powered) 0xff_aa_44_22 else 0xff_44_44_44,
                            .locker => color = 0xff_88_88_44,
                            else => {},
                        }
                    }
                }
            }
            drawTile(draw_list, px, py, l.tile_size, color);
        }
    }

    // Render items on ground
    const item_color: u32 = 0xff44cc88; // green-ish
    for (game.state.run.items.instances[0..game.state.run.items.count]) |*inst| {
        if (inst.x < 0) continue; // in inventory
        if (!game.state.run.visibility.isVisible(inst.x, inst.y)) continue;
        const def = item_def.getById(inst.def_id) orelse continue;
        const px = l.map_origin_x + inst.x * l.tile_size;
        const py = l.map_origin_y + inst.y * l.tile_size;
        draw_list.addTextExtendedUnformatted(
            .{ @floatFromInt(px + scaledPixels(6, l.scale)), @floatFromInt(py + scaledPixels(4, l.scale)) },
            item_color,
            &[_]u8{def.glyph},
            .{ .font = null, .font_size = actor_font_size * l.scale },
        );
    }

    for (game.state.run.actors.enemiesSlice()) |enemy| {
        if (!enemy.alive) continue;
        if (!game.state.run.visibility.isVisible(enemy.position.x, enemy.position.y)) continue;
        drawActor(draw_list, enemy.position.x, enemy.position.y, l, palette.enemy, &[_]u8{enemy.glyph});
    }

    drawActor(draw_list, game.state.run.player.position.x, game.state.run.player.position.y, l, palette.player, "@");
}

fn drawTile(draw_list: zgui.DrawList, x: i32, y: i32, size: i32, color: u32) void {
    draw_list.addRectFilled(.{
        .pmin = .{ @floatFromInt(x), @floatFromInt(y) },
        .pmax = .{ @floatFromInt(x + size), @floatFromInt(y + size) },
        .col = color,
    });
    draw_list.addRect(.{
        .pmin = .{ @floatFromInt(x), @floatFromInt(y) },
        .pmax = .{ @floatFromInt(x + size), @floatFromInt(y + size) },
        .col = palette.grid,
    });
}

fn drawActor(draw_list: zgui.DrawList, x: i32, y: i32, l: render.Layout, color: u32, label: []const u8) void {
    const px = l.map_origin_x + x * l.tile_size;
    const py = l.map_origin_y + y * l.tile_size;
    const inset = scaledPixels(4, l.scale);
    draw_list.addRectFilled(.{
        .pmin = .{ @floatFromInt(px + inset), @floatFromInt(py + inset) },
        .pmax = .{ @floatFromInt(px + l.tile_size - inset), @floatFromInt(py + l.tile_size - inset) },
        .col = color,
        .rounding = 5.0 * l.scale,
    });
    draw_list.addTextExtendedUnformatted(
        .{ @floatFromInt(px + scaledPixels(8, l.scale)), @floatFromInt(py + scaledPixels(4, l.scale)) },
        palette.background,
        label,
        .{ .font = null, .font_size = actor_font_size * l.scale },
    );
}

fn drawLog(game: *const Game, l: render.Layout) void {
    zgui.setNextWindowPos(.{ .x = 0, .y = @floatFromInt(l.log_origin_y - l.padding), .cond = .always });
    zgui.setNextWindowSize(.{ .w = @floatFromInt(l.window_width), .h = @floatFromInt(l.log_height + l.padding), .cond = .always });
    if (zgui.begin("Messages", .{ .flags = fixedPanelFlags() })) {
        zgui.textColored(colorFloats(palette.text), "Messages", .{});
        var i: usize = 0;
        while (i < game.state.run.log.count()) : (i += 1) {
            zgui.textColored(colorFloats(palette.muted), "- {s}", .{game.state.run.log.at(i)});
        }
    }
    zgui.end();
}

fn zoneColor(zone: procgen.ZoneType) u32 {
    return switch (zone) {
        .habitation => 0x40_44_88_44, // green tint
        .labs       => 0x40_44_44_aa, // blue tint
        .reactor    => 0x40_22_66_cc, // orange tint
        .security   => 0x40_44_44_cc, // red tint
        .cargo      => 0x40_88_66_44, // brown tint
        .medbay     => 0x40_88_cc_cc, // cyan tint
        .data_core  => 0x40_cc_44_cc, // purple tint
        .maintenance => 0x40_55_55_55, // grey tint
    };
}

fn drawZoneOverlay(game: *const Game, l: render.Layout) void {
    const draw_list = zgui.getBackgroundDrawList();
    const rs = &game.state.run;
    for (rs.rooms[0..rs.room_count]) |room| {
        const px = l.map_origin_x + @as(i32, @intCast(room.x)) * l.tile_size;
        const py = l.map_origin_y + @as(i32, @intCast(room.y)) * l.tile_size;
        const pw = @as(i32, @intCast(room.w)) * l.tile_size;
        const ph = @as(i32, @intCast(room.h)) * l.tile_size;
        draw_list.addRectFilled(.{
            .pmin = .{ @floatFromInt(px), @floatFromInt(py) },
            .pmax = .{ @floatFromInt(px + pw), @floatFromInt(py + ph) },
            .col = zoneColor(room.zone),
        });
        // Zone label at top-left of room
        draw_list.addText(
            .{ @floatFromInt(px + 2), @floatFromInt(py + 2) },
            0xff_ff_ff_ff,
            "{s}",
            .{@tagName(room.zone)},
        );
    }
}

fn drawInventory(game: *const Game, fps: f32) void {
    _ = fps;
    const rs = &game.state.run;
    const inv = &rs.player.inventory;
    zgui.setNextWindowPos(.{ .x = 80, .y = 80, .cond = .always });
    zgui.setNextWindowSize(.{ .w = 300, .h = 360, .cond = .always });
    if (zgui.begin("Inventory", .{ .flags = .{ .no_saved_settings = true } })) {
        zgui.text("HP: {d}/{d}", .{ rs.player.hp, rs.player.max_hp });
        zgui.separator();
        zgui.text("Inventory ({d}/{d})", .{ inv.count, inventory_mod.max_inventory });
        zgui.separator();
        for (inv.items) |slot| {
            const item_id = slot orelse continue;
            const inst = rs.items.getItem(item_id) orelse continue;
            const def = item_def.getById(inst.def_id) orelse continue;
            const equipped = inv.equipment.isEquipped(item_id);
            if (equipped) {
                zgui.textColored(colorFloats(0xff44cc88), "  [{c}] {s} [E]", .{ def.glyph, def.name });
            } else {
                zgui.text("  [{c}] {s}", .{ def.glyph, def.name });
            }
        }
        zgui.separator();
        zgui.text("Equipped Slots:", .{});
        for (inv.equipment.slots, 0..) |maybe_eid, slot_idx| {
            const eid = maybe_eid orelse continue;
            const inst = rs.items.getItem(eid) orelse continue;
            const def = item_def.getById(inst.def_id) orelse continue;
            const slot: inventory_mod.EquipSlot = @enumFromInt(slot_idx);
            zgui.text("  {s}: {s}", .{ @tagName(slot), def.name });
        }
        zgui.separator();
        zgui.textDisabled("Press I to close | G to pick up", .{});
    }
    zgui.end();
}

fn drawDebug(game: *const Game, fps: f32) void {
    const run_state = &game.state.run;
    const actor_count = run_state.actors.enemyCount() + 1; // +1 for player
    if (zgui.begin("Debug", .{ .flags = .{ .no_saved_settings = true } })) {
        zgui.text("Seed:   {d}", .{run_state.run_seed});
        zgui.text("Floor:  {d}", .{run_state.current_floor});
        zgui.text("Actors: {d}", .{actor_count});
        zgui.text("Turn:   {d}", .{run_state.turn_count});
        zgui.text("Mode:   {s}", .{@tagName(game.state.current_mode)});
        zgui.text("FPS:    {d:.1}", .{fps});
        zgui.text("Alert:  {d}", .{run_state.alert_level});
    }
    zgui.end();
}

fn fixedPanelFlags() zgui.WindowFlags {
    return .{
        .no_title_bar = true,
        .no_resize = true,
        .no_move = true,
        .no_collapse = true,
        .no_saved_settings = true,
        .no_scrollbar = true,
    };
}

fn colorFloats(color: u32) [4]f32 {
    const r: f32 = @floatFromInt(color & 0xff);
    const g: f32 = @floatFromInt((color >> 8) & 0xff);
    const b: f32 = @floatFromInt((color >> 16) & 0xff);
    const a: f32 = @floatFromInt((color >> 24) & 0xff);
    return .{ r / 255.0, g / 255.0, b / 255.0, a / 255.0 };
}

fn scaledPixels(value: i32, scale: f32) i32 {
    return @intFromFloat(@round(@as(f32, @floatFromInt(value)) * scale));
}
