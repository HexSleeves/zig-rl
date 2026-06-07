/// Content validation tool — run via `zig build validate`
/// Checks assets/config/items.json and assets/config/enemies.json for:
///   - valid JSON structure
///   - unique IDs within each file
///   - stat values within allowed ranges
///   - at least one entry per file
const std = @import("std");
const Io = std.Io;
const item_loader = @import("zig_rl").items.item_loader;

const ITEM_PATH = "assets/config/items.json";
const ENEMY_PATH = "assets/config/enemies.json";

const MAX_HP: u32 = 200;
const MAX_DAMAGE: i32 = 100;
const MAX_ARMOR: u32 = 20;
const MAX_ACCURACY: u32 = 100;
const MAX_EVASION: u32 = 100;
const MAX_RANGE: u32 = 20;
const MAX_VALUE: u32 = 10000;

var errors: u32 = 0;

fn fail(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("  FAIL: " ++ fmt ++ "\n", args);
    errors += 1;
}

fn ok(comptime fmt: []const u8, args: anytype) void {
    std.debug.print("  ok:   " ++ fmt ++ "\n", args);
}

fn validateItems(io: Io) !void {
    std.debug.print("\n[items.json]\n", .{});
    const n = item_loader.loadFromFile(io, ITEM_PATH) catch |err| {
        fail("failed to load {s}: {}", .{ ITEM_PATH, err });
        return;
    };
    if (n == 0) { fail("no items defined", .{}); return; }
    ok("{d} items loaded", .{n});

    var seen = std.bit_set.StaticBitSet(512).initEmpty();
    for (item_loader.getAll()) |def| {
        if (def.id >= 512) { fail("item id {d} >= 512", .{def.id}); continue; }
        if (seen.isSet(def.id)) fail("duplicate id {d} ({s})", .{ def.id, def.name });
        seen.set(def.id);
        if (def.name.len == 0) fail("item {d} empty name", .{def.id});
        if (def.damage_max > MAX_DAMAGE) fail("item {d} damage_max {d} > {d}", .{ def.id, def.damage_max, MAX_DAMAGE });
        if (def.damage_min > def.damage_max and def.damage_max > 0) fail("item {d} damage_min > damage_max", .{def.id});
        if (def.armor_bonus > MAX_ARMOR) fail("item {d} armor_bonus {d} > {d}", .{ def.id, def.armor_bonus, MAX_ARMOR });
        if (def.range > MAX_RANGE) fail("item {d} range {d} > {d}", .{ def.id, def.range, MAX_RANGE });
        if (def.value > MAX_VALUE) fail("item {d} value {d} > {d}", .{ def.id, def.value, MAX_VALUE });
    }
    ok("IDs unique, stats valid", .{});
}

fn validateEnemies(io: Io) !void {
    std.debug.print("\n[enemies.json]\n", .{});
    var file_buf: [16384]u8 = undefined;
    const file = Io.Dir.cwd().openFile(io, ENEMY_PATH, .{}) catch |err| {
        fail("failed to open {s}: {}", .{ ENEMY_PATH, err });
        return;
    };
    defer file.close(io);
    const n = try file.readPositionalAll(io, &file_buf, 0);

    var arena_buf: [65536]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const parsed = try std.json.parseFromSlice(std.json.Value, fba.allocator(), file_buf[0..n], .{});
    defer parsed.deinit();

    const arr = switch (parsed.value) {
        .array => |a| a,
        else => { fail("root not array", .{}); return; },
    };
    if (arr.items.len == 0) { fail("no enemies defined", .{}); return; }
    ok("{d} enemies loaded", .{arr.items.len});

    var seen = std.bit_set.StaticBitSet(256).initEmpty();
    for (arr.items) |val| {
        const obj = switch (val) {
            .object => |o| o,
            else => { fail("entry not object", .{}); continue; },
        };
        const id: u32 = if (obj.get("id")) |v| @intCast(v.integer) else 0;
        const hp: u32 = if (obj.get("hp")) |v| @intCast(v.integer) else 0;
        const armor: u32 = if (obj.get("armor")) |v| @intCast(v.integer) else 0;
        const accuracy: u32 = if (obj.get("accuracy")) |v| @intCast(v.integer) else 0;
        const evasion: u32 = if (obj.get("evasion")) |v| @intCast(v.integer) else 0;
        const speed: u32 = if (obj.get("speed")) |v| @intCast(v.integer) else 0;
        const has_name = if (obj.get("name")) |v| v.string.len > 0 else false;

        if (id >= 256) { fail("enemy id {d} >= 256", .{id}); continue; }
        if (seen.isSet(id)) fail("duplicate enemy id {d}", .{id});
        seen.set(id);
        if (!has_name) fail("enemy {d} empty name", .{id});
        if (hp == 0) fail("enemy {d} hp is 0", .{id});
        if (hp > MAX_HP) fail("enemy {d} hp {d} > {d}", .{ id, hp, MAX_HP });
        if (armor > MAX_ARMOR) fail("enemy {d} armor {d} > {d}", .{ id, armor, MAX_ARMOR });
        if (accuracy > MAX_ACCURACY) fail("enemy {d} accuracy {d} > 100", .{ id, accuracy });
        if (evasion > MAX_EVASION) fail("enemy {d} evasion {d} > 100", .{ id, evasion });
        if (speed == 0) fail("enemy {d} speed is 0", .{id});
    }
    ok("IDs unique, stats valid", .{});
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    std.debug.print("=== zig-rl content validation ===\n", .{});
    try validateItems(io);
    try validateEnemies(io);
    std.debug.print("\n", .{});
    if (errors > 0) {
        std.debug.print("VALIDATION FAILED — {d} error(s)\n", .{errors});
        std.process.exit(1);
    }
    std.debug.print("VALIDATION PASSED\n", .{});
}
