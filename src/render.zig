const config = @import("config.zig");

pub const backend_name = "zig-gamedev/zglfw+zopengl+zgui";

pub const Layout = struct {
    scale: f32,
    tile_size: i32,
    padding: i32,
    hud_height: i32,
    log_height: i32,
    map_width_pixels: i32,
    map_height_pixels: i32,
    window_width: i32,
    window_height: i32,
    map_origin_x: i32,
    map_origin_y: i32,
    log_origin_y: i32,
};

pub fn layout() Layout {
    return layoutForScale(1.0);
}

pub fn layoutForScale(scale: f32) Layout {
    const tile_size = scaleUsize(config.tile_size_pixels, scale);
    const map_width_pixels = scaleUsize(config.map_width * config.tile_size_pixels, scale);
    const map_height_pixels = scaleUsize(config.map_height * config.tile_size_pixels, scale);
    const padding = scaleI32(config.window_padding_pixels, scale);
    const hud_height = scaleI32(config.hud_height_pixels, scale);
    const log_height = scaleI32(config.log_height_pixels, scale);
    const map_origin_y = padding + hud_height;

    return .{
        .scale = scale,
        .tile_size = tile_size,
        .padding = padding,
        .hud_height = hud_height,
        .log_height = log_height,
        .map_width_pixels = map_width_pixels,
        .map_height_pixels = map_height_pixels,
        .window_width = map_width_pixels + padding * 2,
        .window_height = map_origin_y + map_height_pixels + log_height + padding,
        .map_origin_x = padding,
        .map_origin_y = map_origin_y,
        .log_origin_y = map_origin_y + map_height_pixels + padding,
    };
}

fn scaleUsize(value: usize, scale: f32) i32 {
    return @intFromFloat(@round(@as(f32, @floatFromInt(value)) * scale));
}

fn scaleI32(value: i32, scale: f32) i32 {
    return @intFromFloat(@round(@as(f32, @floatFromInt(value)) * scale));
}
