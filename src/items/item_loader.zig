const std = @import("std");
const Io = std.Io;
const item_def = @import("item_def.zig");

pub const MAX_LOADED = 64;

var g_defs: [MAX_LOADED]item_def.ItemDef = undefined;
var g_count: usize = 0;
var g_name_buf: [8192]u8 = undefined;
var g_name_cursor: usize = 0;
var g_loaded: bool = false;

fn internString(src: []const u8) []const u8 {
    const start = g_name_cursor;
    const len = @min(src.len, g_name_buf.len - g_name_cursor - 1);
    @memcpy(g_name_buf[start .. start + len], src[0..len]);
    g_name_cursor += len;
    return g_name_buf[start .. start + len];
}

fn parseKind(s: []const u8) !item_def.ItemKind {
    if (std.mem.eql(u8, s, "weapon")) return .weapon;
    if (std.mem.eql(u8, s, "ammo")) return .ammo;
    if (std.mem.eql(u8, s, "armor")) return .armor;
    if (std.mem.eql(u8, s, "implant")) return .implant;
    if (std.mem.eql(u8, s, "tool")) return .tool;
    if (std.mem.eql(u8, s, "consumable")) return .consumable;
    if (std.mem.eql(u8, s, "keycard")) return .keycard;
    if (std.mem.eql(u8, s, "quest_data")) return .quest_data;
    if (std.mem.eql(u8, s, "crafting_part")) return .crafting_part;
    return error.UnknownItemKind;
}

/// Load items from JSON into the global table. Safe to call multiple times
/// (resets state each call). Returns number of items loaded.
pub fn loadFromFile(io: Io, path: []const u8) !usize {
    g_count = 0;
    g_name_cursor = 0;
    g_loaded = false;

    var file_buf: [65536]u8 = undefined;
    const file = try Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const n = try file.readPositionalAll(io, &file_buf, 0);

    var arena_buf: [131072]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&arena_buf);
    const allocator = fba.allocator();

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, file_buf[0..n], .{});
    defer parsed.deinit();

    const arr = switch (parsed.value) {
        .array => |a| a,
        else => return error.ExpectedArray,
    };

    for (arr.items) |item_val| {
        if (g_count >= MAX_LOADED) return error.TooManyItems;
        const obj = switch (item_val) {
            .object => |o| o,
            else => return error.ExpectedObject,
        };

        var def = item_def.ItemDef{
            .id = 0,
            .name = "",
            .glyph = '?',
            .kind = .tool,
        };

        if (obj.get("id")) |v| def.id = @intCast(v.integer);
        if (obj.get("name")) |v| def.name = internString(v.string);
        if (obj.get("glyph")) |v| def.glyph = if (v.string.len > 0) v.string[0] else '?';
        if (obj.get("kind")) |v| def.kind = try parseKind(v.string);
        if (obj.get("damage_min")) |v| def.damage_min = @intCast(v.integer);
        if (obj.get("damage_max")) |v| def.damage_max = @intCast(v.integer);
        if (obj.get("accuracy_bonus")) |v| def.accuracy_bonus = @intCast(v.integer);
        if (obj.get("range")) |v| def.range = @intCast(v.integer);
        if (obj.get("mag_size")) |v| def.mag_size = @intCast(v.integer);
        if (obj.get("armor_bonus")) |v| def.armor_bonus = @intCast(v.integer);
        if (obj.get("evasion_bonus")) |v| def.evasion_bonus = @intCast(v.integer);
        if (obj.get("evasion_penalty")) |v| def.evasion_penalty = @intCast(v.integer);
        if (obj.get("heal_amount")) |v| def.heal_amount = @intCast(v.integer);
        if (obj.get("charges")) |v| def.charges = @intCast(v.integer);
        if (obj.get("value")) |v| def.value = @intCast(v.integer);
        if (obj.get("stack_max")) |v| def.stack_max = @intCast(v.integer);

        g_defs[g_count] = def;
        g_count += 1;
    }

    g_loaded = true;
    return g_count;
}

pub fn isLoaded() bool {
    return g_loaded;
}

pub fn getById(id: u16) ?*const item_def.ItemDef {
    for (g_defs[0..g_count]) |*def| {
        if (def.id == id) return def;
    }
    return null;
}

pub fn getAll() []const item_def.ItemDef {
    return g_defs[0..g_count];
}

pub fn count() usize {
    return g_count;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "parseKind covers all variants" {
    try std.testing.expectEqual(item_def.ItemKind.weapon, try parseKind("weapon"));
    try std.testing.expectEqual(item_def.ItemKind.consumable, try parseKind("consumable"));
    try std.testing.expectEqual(item_def.ItemKind.crafting_part, try parseKind("crafting_part"));
    try std.testing.expectError(error.UnknownItemKind, parseKind("banana"));
}

test "internString stores and returns correct slice" {
    g_name_cursor = 0;
    const s = internString("medkit");
    try std.testing.expectEqualStrings("medkit", s);
}
