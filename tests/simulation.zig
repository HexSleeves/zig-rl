const std = @import("std");

const rl = @import("zig_rl");
const config = rl.config;
const generation = rl.world.generation;
const movement = rl.systems.movement;
const render = rl.render;
const State = rl.State;

test "starter dungeon has fixed dimensions, boundary walls, and walkable player spawn" {
    var map = generation.generateStarterDungeon();

    try std.testing.expectEqual(@as(usize, config.map_width), map.width);
    try std.testing.expectEqual(@as(usize, config.map_height), map.height);
    try std.testing.expect(map.isBlocked(0, 0));
    try std.testing.expect(map.isBlocked(config.map_width - 1, config.map_height - 1));
    try std.testing.expect(!map.isBlocked(config.player_start_x, config.player_start_y));
}

test "player movement respects walls and advances turns only for valid movement" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    try std.testing.expectEqual(@as(i32, config.player_start_x), state.run.player.position.x);
    try std.testing.expectEqual(@as(u64, 0), state.run.turn_count);

    const hit_wall = try movement.tryMovePlayer(&state, .west);
    try std.testing.expectEqual(movement.MoveResult.blocked, hit_wall);
    try std.testing.expectEqual(@as(i32, config.player_start_x), state.run.player.position.x);
    try std.testing.expectEqual(@as(u64, 0), state.run.turn_count);

    const moved = try movement.tryMovePlayer(&state, .east);
    try std.testing.expectEqual(movement.MoveResult.moved, moved);
    try std.testing.expectEqual(@as(i32, config.player_start_x + 1), state.run.player.position.x);
    try std.testing.expectEqual(@as(u64, 1), state.run.turn_count);
}

test "message log keeps the newest entries within capacity" {
    var state = try State.init(std.testing.allocator);
    defer state.deinit();

    try state.run.log.add("first");
    try state.run.log.add("second");
    try state.run.log.add("third");
    try state.run.log.add("fourth");
    try state.run.log.add("fifth");
    try state.run.log.add("sixth");

    try std.testing.expectEqual(@as(usize, config.max_log_messages), state.run.log.count());
    try std.testing.expectEqualStrings("second", state.run.log.at(0));
    try std.testing.expectEqualStrings("sixth", state.run.log.at(state.run.log.count() - 1));
}

test "native window layout fits the map plus HUD and message log" {
    const layout = render.layout();

    try std.testing.expectEqual(@as(i32, @intCast(config.map_width * config.tile_size_pixels)), layout.map_width_pixels);
    try std.testing.expectEqual(@as(i32, @intCast(config.map_height * config.tile_size_pixels)), layout.map_height_pixels);
    try std.testing.expect(layout.window_width >= layout.map_width_pixels);
    try std.testing.expect(layout.window_height > layout.map_height_pixels);
}

test "native window layout scales for high density framebuffers" {
    const layout = render.layoutForScale(2);

    try std.testing.expectEqual(@as(i32, @intCast(config.tile_size_pixels * 2)), layout.tile_size);
    try std.testing.expectEqual(@as(i32, @intCast(config.map_width * config.tile_size_pixels * 2)), layout.map_width_pixels);
    try std.testing.expectEqual(layout.map_width_pixels + layout.padding * 2, layout.window_width);
    try std.testing.expectEqual(layout.map_origin_y + layout.map_height_pixels + layout.log_height + layout.padding, layout.window_height);
}

test "native renderer is backed by zig-gamedev libraries" {
    try std.testing.expectEqualStrings("zig-gamedev/zglfw+zopengl+zgui", render.backend_name);
}
