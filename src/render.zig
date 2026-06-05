const config = @import("config.zig");

pub const backend_name = "zig-gamedev/zglfw+zopengl+zgui";

pub const Layout = struct {
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
    const tile_size: i32 = @intCast(config.tile_size_pixels);
    const map_width_pixels: i32 = @intCast(config.map_width * config.tile_size_pixels);
    const map_height_pixels: i32 = @intCast(config.map_height * config.tile_size_pixels);
    const padding = config.window_padding_pixels;
    const map_origin_y = padding + config.hud_height_pixels;

    return .{
        .tile_size = tile_size,
        .padding = padding,
        .hud_height = config.hud_height_pixels,
        .log_height = config.log_height_pixels,
        .map_width_pixels = map_width_pixels,
        .map_height_pixels = map_height_pixels,
        .window_width = map_width_pixels + padding * 2,
        .window_height = map_origin_y + map_height_pixels + config.log_height_pixels + padding,
        .map_origin_x = padding,
        .map_origin_y = map_origin_y,
        .log_origin_y = map_origin_y + map_height_pixels + padding,
    };
}
