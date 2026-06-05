const std = @import("std");
const zglfw = @import("zglfw");
const zgui = @import("zgui");
const zopengl = @import("zopengl");

const Game = @import("game.zig").Game;
const config = @import("config.zig");
const input = @import("input.zig");
const render = @import("render.zig");

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

    while (!window.shouldClose() and !game.state.quit_requested) {
        zglfw.pollEvents();
        if (readCommand(window, &input_state)) |command| {
            try game.handle(command);
        }

        const fb_size = window.getFramebufferSize();
        gl.viewport(0, 0, fb_size[0], fb_size[1]);
        gl.clearColor(0.071, 0.078, 0.094, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT);

        zgui.backend.newFrame(@intCast(fb_size[0]), @intCast(fb_size[1]));
        const l = render.layoutForScale(framebufferScale(base_layout, fb_size));
        drawGame(game, l);
        zgui.backend.draw();

        window.swapBuffers();

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
    if (pressedAny(window, &state.west, &.{ .a, .h, .left })) return .{ .move = .west };
    if (pressedAny(window, &state.east, &.{ .d, .l, .right })) return .{ .move = .east };
    if (pressedAny(window, &state.wait, &.{ .period, .space })) return .wait;
    if (pressedAny(window, &state.quit, &.{ .q, .escape })) return .quit;
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

fn drawGame(game: *const Game, l: render.Layout) void {
    zgui.pushFont(null, base_font_size * l.scale);
    defer zgui.popFont();

    drawMap(game, l);
    drawHud(game, l);
    drawLog(game, l);
}

fn drawHud(game: *const Game, l: render.Layout) void {
    zgui.setNextWindowPos(.{ .x = 0, .y = 0, .cond = .always });
    zgui.setNextWindowSize(.{ .w = @floatFromInt(l.window_width), .h = @floatFromInt(l.map_origin_y), .cond = .always });
    if (zgui.begin("HUD", .{ .flags = fixedPanelFlags() })) {
        zgui.text("zig-rl", .{});
        zgui.sameLine(.{});
        zgui.textDisabled("WASD/HJKL/arrows move   . waits   Q/Esc quits", .{});
        zgui.sameLine(.{ .spacing = 32 });
        zgui.text("Turn {d}", .{game.state.run.turn_count});
    }
    zgui.end();
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
            const color = switch (game.state.run.map.get(x, y).kind) {
                .wall => palette.wall,
                .floor => palette.floor,
            };
            drawTile(draw_list, px, py, l.tile_size, color);
        }
    }

    for (game.state.run.actors.enemiesSlice()) |enemy| {
        if (enemy.alive) {
            drawActor(draw_list, enemy.position.x, enemy.position.y, l, palette.enemy, "g");
        }
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
