/// Floor simulation tool — run via `zig build simulate`
/// Generates N floors and reports: room counts, enemy density,
/// loot distribution, door/terminal/camera counts.
const std = @import("std");
const zig_rl = @import("zig_rl");
const procgen = zig_rl.world.procgen;
const rng_mod = zig_rl.rng;

const RUNS: u32 = 1000;
const BASE_SEED: u64 = 0xDEADBEEF_CAFEBABE;

pub fn main() void {
    std.debug.print("=== zig-rl floor simulation ({d} runs) ===\n\n", .{RUNS});

    var total_rooms: u64 = 0;
    var total_enemies: u64 = 0;
    var total_items: u64 = 0;
    var total_doors: u64 = 0;
    var total_terminals: u64 = 0;
    var total_cameras: u64 = 0;
    var min_rooms: u32 = std.math.maxInt(u32);
    var max_rooms: u32 = 0;
    var min_enemies: u32 = std.math.maxInt(u32);
    var max_enemies_seen: u32 = 0;
    var zero_enemy_floors: u32 = 0;
    var zero_loot_floors: u32 = 0;
    var enemy_hist = [_]u32{0} ** 16;
    var room_hist = [_]u32{0} ** 16;

    var i: u32 = 0;
    while (i < RUNS) : (i += 1) {
        var rng = rng_mod.Rng.init(BASE_SEED +% i);
        const floor = procgen.generate(&rng, 1);

        const rooms: u32 = @intCast(floor.room_count);
        total_rooms += rooms;
        if (rooms < min_rooms) min_rooms = rooms;
        if (rooms > max_rooms) max_rooms = rooms;
        if (rooms < room_hist.len) room_hist[rooms] += 1;

        var enemies: u32 = 0;
        for (floor.spawns[0..floor.spawn_count]) |sp| {
            if (sp.kind == .enemy) enemies += 1;
        }
        total_enemies += enemies;
        total_items += floor.spawn_count; // proxy: all spawns as loot metric
        if (enemies < min_enemies) min_enemies = enemies;
        if (enemies > max_enemies_seen) max_enemies_seen = enemies;
        if (enemies == 0) zero_enemy_floors += 1;
        if (floor.spawn_count == 0) zero_loot_floors += 1;
        if (enemies < enemy_hist.len) enemy_hist[enemies] += 1;

        total_doors += floor.door_count;
        total_terminals += floor.terminal_count;
        total_cameras += floor.camera_count;
    }

    const r: f64 = @floatFromInt(RUNS);

    std.debug.print("Rooms:\n", .{});
    std.debug.print("  avg {d:.1}  min {d}  max {d}\n", .{ @as(f64, @floatFromInt(total_rooms)) / r, min_rooms, max_rooms });
    std.debug.print("  histogram:", .{});
    for (room_hist, 0..) |cnt, n| if (cnt > 0) std.debug.print(" {d}x{d}", .{ n, cnt });
    std.debug.print("\n\n", .{});

    std.debug.print("Enemies:\n", .{});
    std.debug.print("  avg {d:.1}  min {d}  max {d}  zero-enemy: {d}/{d}\n", .{
        @as(f64, @floatFromInt(total_enemies)) / r, min_enemies, max_enemies_seen, zero_enemy_floors, RUNS,
    });
    std.debug.print("  histogram:", .{});
    for (enemy_hist, 0..) |cnt, n| if (cnt > 0) std.debug.print(" {d}x{d}", .{ n, cnt });
    std.debug.print("\n\n", .{});

    std.debug.print("Loot:\n", .{});
    std.debug.print("  avg {d:.1}  zero-loot: {d}/{d}\n\n", .{
        @as(f64, @floatFromInt(total_items)) / r, zero_loot_floors, RUNS,
    });

    std.debug.print("Objects:\n", .{});
    std.debug.print("  doors avg {d:.1}  terminals avg {d:.1}  cameras avg {d:.1}\n", .{
        @as(f64, @floatFromInt(total_doors)) / r,
        @as(f64, @floatFromInt(total_terminals)) / r,
        @as(f64, @floatFromInt(total_cameras)) / r,
    });
    std.debug.print("\nDone.\n", .{});
}
