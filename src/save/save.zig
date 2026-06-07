const std = @import("std");
const Io = std.Io;
const campaign_mod = @import("../campaign_state.zig");
const run_state_mod = @import("../run_state.zig");
const tile_mod = @import("../world/tile.zig");
const map_object_mod = @import("../world/map_object.zig");
const ids_mod = @import("../ids.zig");
const item_store_mod = @import("../stores/item_store.zig");
const object_store_mod = @import("../stores/object_store.zig");
const actor_store_mod = @import("../stores/actor_store.zig");
const energy_sched_mod = @import("../energy_scheduler.zig");
const enemy_mod = @import("../entities/enemy.zig");
const config = @import("../config.zig");

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

pub const SAVE_VERSION: u32 = 1;

const CAMPAIGN_MAGIC = "ZRLC".*;
const RUN_MAGIC = "ZRLR".*;
const REPLAY_MAGIC = "ZRLY".*;

pub const CAMPAIGN_PATH = "saves/campaign.sav";
pub const RUN_PATH = "saves/run.sav";
pub const REPLAY_PATH = "saves/replay.log";

pub const SaveError = error{
    SaveVersionMismatch,
    InvalidMagic,
};

// ---------------------------------------------------------------------------
// Replay command byte encoding
// ---------------------------------------------------------------------------

pub const CommandByte = enum(u8) {
    none = 0,
    move_north = 1,
    move_south = 2,
    move_east = 3,
    move_west = 4,
    move_northeast = 5,
    move_northwest = 6,
    move_southeast = 7,
    move_southwest = 8,
    wait = 9,
    quit = 10,
    pickup = 11,
    hack = 12,
};

// ---------------------------------------------------------------------------
// In-memory buffer writer / reader (replaces std.io.fixedBufferStream)
// ---------------------------------------------------------------------------

const BufWriter = struct {
    buf: []u8,
    pos: usize = 0,

    fn writeAll(self: *BufWriter, data: []const u8) error{NoSpaceLeft}!void {
        if (self.pos + data.len > self.buf.len) return error.NoSpaceLeft;
        @memcpy(self.buf[self.pos..][0..data.len], data);
        self.pos += data.len;
    }

    fn writeInt(self: *BufWriter, comptime T: type, value: T, endian: std.builtin.Endian) error{NoSpaceLeft}!void {
        var tmp: [@sizeOf(T)]u8 = undefined;
        std.mem.writeInt(T, &tmp, value, endian);
        try self.writeAll(&tmp);
    }

    fn getWritten(self: *const BufWriter) []const u8 {
        return self.buf[0..self.pos];
    }
};

const BufReader = struct {
    buf: []const u8,
    pos: usize = 0,

    fn readNoEof(self: *BufReader, dest: []u8) error{EndOfStream}!void {
        if (self.pos + dest.len > self.buf.len) return error.EndOfStream;
        @memcpy(dest, self.buf[self.pos..][0..dest.len]);
        self.pos += dest.len;
    }

    fn readInt(self: *BufReader, comptime T: type, endian: std.builtin.Endian) error{EndOfStream}!T {
        var tmp: [@sizeOf(T)]u8 = undefined;
        try self.readNoEof(&tmp);
        return std.mem.readInt(T, &tmp, endian);
    }
};

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn ensureSaveDir(io: Io) void {
    Io.Dir.cwd().createDir(io, "saves", .default_dir) catch {};
}

fn writeAtomic(io: Io, path: []const u8, data: []const u8) !void {
    var af = try Io.Dir.cwd().createFileAtomic(io, path, .{ .replace = true });
    defer af.deinit(io);
    try af.file.writePositionalAll(io, data, 0);
    try af.replace(io);
}

fn bitset32ToU32(bs: *const std.bit_set.StaticBitSet(32)) u32 {
    var v: u32 = 0;
    var i: usize = 0;
    while (i < 32) : (i += 1) {
        if (bs.isSet(i)) v |= @as(u32, 1) << @intCast(i);
    }
    return v;
}

fn u32ToBitset32(v: u32) std.bit_set.StaticBitSet(32) {
    var bs = std.bit_set.StaticBitSet(32).initEmpty();
    var i: u5 = 0;
    while (i < 32) : (i +%= 1) {
        if (v & (@as(u32, 1) << i) != 0) bs.set(i);
        if (i == 31) break;
    }
    return bs;
}

fn bitsetNToU8(bs: anytype, comptime N: usize) u8 {
    var v: u8 = 0;
    var i: usize = 0;
    while (i < N) : (i += 1) {
        if (bs.isSet(i)) v |= @as(u8, 1) << @intCast(i);
    }
    return v;
}

fn encodeTile(tile: tile_mod.Tile) u8 {
    return switch (tile.kind) {
        .wall => 0,
        .floor => 1,
        .door => if (tile.blocks_sight) 2 else 3,
    };
}

fn decodeTile(encoded: u8) tile_mod.Tile {
    return switch (encoded) {
        0 => tile_mod.Tile.wall(),
        1 => tile_mod.Tile.floor(),
        2 => tile_mod.Tile.door_closed(),
        3 => tile_mod.Tile.door_open(),
        else => tile_mod.Tile.wall(),
    };
}

fn glyphToName(glyph: u8) []const u8 {
    return switch (glyph) {
        'g' => "guard",
        's' => "sentinel",
        'r' => "rogue",
        'e' => "enforcer",
        else => "unknown",
    };
}

fn u8ToBitsetN(v: u8, comptime N: usize) std.bit_set.StaticBitSet(N) {
    var bs = std.bit_set.StaticBitSet(N).initEmpty();
    var i: usize = 0;
    while (i < N) : (i += 1) {
        if (v & (@as(u8, 1) << @intCast(i)) != 0) bs.set(i);
    }
    return bs;
}

// ---------------------------------------------------------------------------
// Campaign save / load
// ---------------------------------------------------------------------------

pub fn saveCampaign(io: Io, campaign: *const campaign_mod.CampaignState) !void {
    ensureSaveDir(io);
    var buf: [8192]u8 = undefined;
    var w = BufWriter{ .buf = &buf };

    try w.writeAll(&CAMPAIGN_MAGIC);
    try w.writeInt(u32, SAVE_VERSION, .little);

    try w.writeInt(u32, bitset32ToU32(&campaign.unlocked_items), .little);
    try w.writeInt(u8, bitsetNToU8(&campaign.unlocked_backgrounds, campaign_mod.BACKGROUND_COUNT), .little);
    try w.writeInt(u32, bitset32ToU32(&campaign.seen_item_defs), .little);
    try w.writeInt(u32, bitset32ToU32(&campaign.discovered_lore), .little);

    var glyph_lo: u64 = 0;
    var glyph_hi: u64 = 0;
    for (0..64) |i| if (campaign.seen_enemy_glyphs.isSet(i)) {
        glyph_lo |= @as(u64, 1) << @intCast(i);
    };
    for (64..128) |i| if (campaign.seen_enemy_glyphs.isSet(i)) {
        glyph_hi |= @as(u64, 1) << @intCast(i - 64);
    };
    try w.writeInt(u64, glyph_lo, .little);
    try w.writeInt(u64, glyph_hi, .little);

    try w.writeInt(u32, campaign.runs_completed, .little);
    try w.writeInt(u32, campaign.runs_failed, .little);
    try w.writeInt(u32, campaign.best_floor, .little);
    try w.writeInt(u32, campaign.best_score, .little);
    try w.writeInt(u32, campaign.total_kills, .little);
    try w.writeInt(u32, campaign.completed_objectives, .little);

    try w.writeInt(u32, @intCast(campaign.history_count), .little);
    try w.writeInt(u32, @intCast(campaign.history_next), .little);
    for (campaign.run_history) |rec| {
        try w.writeInt(u8, @intFromEnum(rec.outcome), .little);
        try w.writeInt(u32, rec.floor, .little);
        try w.writeInt(u32, rec.score, .little);
        try w.writeInt(u64, rec.turn_count, .little);
        try w.writeInt(u32, rec.kills, .little);
        try w.writeInt(u32, rec.items_found, .little);
    }
    for (campaign.wing_status) |ws| try w.writeInt(u8, @intFromEnum(ws), .little);

    try writeAtomic(io, CAMPAIGN_PATH, w.getWritten());
}

pub fn loadCampaign(io: Io) !campaign_mod.CampaignState {
    var buf: [8192]u8 = undefined;
    const file = Io.Dir.cwd().openFile(io, CAMPAIGN_PATH, .{}) catch
        return campaign_mod.CampaignState.init();
    defer file.close(io);
    const n = try file.readPositionalAll(io, &buf, 0);

    var r = BufReader{ .buf = buf[0..n] };
    var magic: [4]u8 = undefined;
    try r.readNoEof(&magic);
    if (!std.mem.eql(u8, &magic, &CAMPAIGN_MAGIC)) return SaveError.InvalidMagic;
    const version = try r.readInt(u32, .little);
    if (version != SAVE_VERSION) return SaveError.SaveVersionMismatch;

    var c = campaign_mod.CampaignState.init();

    c.unlocked_items = u32ToBitset32(try r.readInt(u32, .little));
    c.unlocked_backgrounds = u8ToBitsetN(try r.readInt(u8, .little), campaign_mod.BACKGROUND_COUNT);
    c.seen_item_defs = u32ToBitset32(try r.readInt(u32, .little));
    c.discovered_lore = u32ToBitset32(try r.readInt(u32, .little));

    const lo = try r.readInt(u64, .little);
    const hi = try r.readInt(u64, .little);
    c.seen_enemy_glyphs = std.bit_set.StaticBitSet(128).initEmpty();
    for (0..64) |i| if (lo & (@as(u64, 1) << @intCast(i)) != 0) c.seen_enemy_glyphs.set(i);
    for (0..64) |i| if (hi & (@as(u64, 1) << @intCast(i)) != 0) c.seen_enemy_glyphs.set(i + 64);

    c.runs_completed = try r.readInt(u32, .little);
    c.runs_failed = try r.readInt(u32, .little);
    c.best_floor = try r.readInt(u32, .little);
    c.best_score = try r.readInt(u32, .little);
    c.total_kills = try r.readInt(u32, .little);
    c.completed_objectives = try r.readInt(u32, .little);

    c.history_count = try r.readInt(u32, .little);
    c.history_next = try r.readInt(u32, .little);
    for (&c.run_history) |*rec| {
        rec.outcome = @enumFromInt(try r.readInt(u8, .little));
        rec.floor = try r.readInt(u32, .little);
        rec.score = try r.readInt(u32, .little);
        rec.turn_count = try r.readInt(u64, .little);
        rec.kills = try r.readInt(u32, .little);
        rec.items_found = try r.readInt(u32, .little);
    }
    for (&c.wing_status) |*ws| ws.* = @enumFromInt(try r.readInt(u8, .little));

    return c;
}

// ---------------------------------------------------------------------------
// Run save / load
// ---------------------------------------------------------------------------

pub fn saveRun(io: Io, run: *const run_state_mod.RunState) !void {
    ensureSaveDir(io);
    var buf: [32768]u8 = undefined;
    var w = BufWriter{ .buf = &buf };

    try w.writeAll(&RUN_MAGIC);
    try w.writeInt(u32, SAVE_VERSION, .little);

    try w.writeInt(u64, run.run_seed, .little);
    for (run.rng.getState()) |s| try w.writeInt(u64, s, .little);
    try w.writeInt(u32, run.current_floor, .little);
    try w.writeInt(u64, run.turn_count, .little);
    try w.writeInt(u32, run.kills, .little);
    try w.writeInt(u32, run.items_found, .little);
    try w.writeInt(u8, run.alert_level, .little);

    // Player
    try w.writeInt(i32, run.player.position.x, .little);
    try w.writeInt(i32, run.player.position.y, .little);
    try w.writeInt(u8, run.player.glyph, .little);
    try w.writeInt(i32, run.player.hp, .little);
    try w.writeInt(i32, run.player.max_hp, .little);
    try w.writeInt(u32, run.player.armor, .little);
    try w.writeInt(u32, run.player.evasion, .little);
    try w.writeInt(u32, @intCast(run.player.inventory.count), .little);
    for (run.player.inventory.items) |slot| {
        try w.writeInt(u32, if (slot) |id| id.value else 0, .little);
    }
    for (run.player.inventory.equipment.slots) |slot| {
        try w.writeInt(u32, if (slot) |id| id.value else 0, .little);
    }

    // Enemies
    try w.writeInt(u32, @intCast(run.actors.enemy_count), .little);
    for (run.actors.enemies[0..run.actors.enemy_count]) |enemy| {
        try w.writeInt(i32, enemy.position.x, .little);
        try w.writeInt(i32, enemy.position.y, .little);
        try w.writeInt(u8, enemy.glyph, .little);
        var name_buf = [_]u8{0} ** 16;
        const nl = @min(enemy.name.len, 15);
        @memcpy(name_buf[0..nl], enemy.name[0..nl]);
        try w.writeAll(&name_buf);
        try w.writeInt(u8, if (enemy.alive) 1 else 0, .little);
        try w.writeInt(i32, enemy.hp, .little);
        try w.writeInt(i32, enemy.max_hp, .little);
        try w.writeInt(u32, enemy.armor, .little);
        try w.writeInt(u32, enemy.accuracy, .little);
        try w.writeInt(u32, enemy.evasion, .little);
        try w.writeInt(u32, enemy.speed, .little);
        try w.writeInt(u32, enemy.faction.value, .little);
        try w.writeInt(u32, enemy.awareness, .little);
        try w.writeInt(u8, @intFromEnum(enemy.ai.mode), .little);
        try w.writeInt(i32, enemy.ai.last_seen_player_x, .little);
        try w.writeInt(i32, enemy.ai.last_seen_player_y, .little);
        try w.writeInt(u32, enemy.ai.turns_since_saw_player, .little);
        try w.writeAll(&enemy.status.durations);
    }

    // Items
    try w.writeInt(u32, @intCast(run.items.count), .little);
    for (run.items.instances[0..run.items.count]) |inst| {
        try w.writeInt(u32, inst.id.value, .little);
        try w.writeInt(u16, inst.def_id, .little);
        try w.writeInt(i32, inst.x, .little);
        try w.writeInt(i32, inst.y, .little);
        try w.writeInt(u32, inst.owner.value, .little);
        try w.writeInt(u32, inst.charges, .little);
        try w.writeInt(u8, inst.condition, .little);
        try w.writeInt(u8, @as(u8, @bitCast(inst.quirks)), .little);
        try w.writeInt(u8, if (inst.identified) 1 else 0, .little);
    }

    // Objects
    try w.writeInt(u32, @intCast(run.objects.count), .little);
    for (run.objects.objects[0..run.objects.count]) |obj| {
        try w.writeInt(u32, obj.id.value, .little);
        try w.writeInt(i32, obj.x, .little);
        try w.writeInt(i32, obj.y, .little);
        try w.writeInt(u8, @intFromEnum(obj.kind), .little);
        try w.writeInt(u8, @intFromEnum(obj.state), .little);
        try w.writeInt(u8, if (obj.powered) 1 else 0, .little);
        try w.writeInt(u8, obj.difficulty, .little);
        try w.writeInt(u8, if (obj.alive) 1 else 0, .little);
        try w.writeInt(u8, obj.facing, .little);
    }

    // Scheduler
    try w.writeInt(u32, @intCast(run.scheduler.count), .little);
    for (run.scheduler.actors[0..run.scheduler.count]) |slot| {
        try w.writeInt(u32, slot.id.value, .little);
        try w.writeInt(i32, slot.energy, .little);
        try w.writeInt(u32, slot.speed, .little);
    }

    // Map tiles
    try w.writeInt(u32, @intCast(config.map_width * config.map_height), .little);
    for (0..config.map_height) |y| {
        for (0..config.map_width) |x| {
            try w.writeInt(u8, encodeTile(run.map.get(@intCast(x), @intCast(y))), .little);
        }
    }

    try writeAtomic(io, RUN_PATH, w.getWritten());
}

pub fn loadRun(io: Io, allocator: std.mem.Allocator) !run_state_mod.RunState {
    var run = try run_state_mod.RunState.init(allocator);
    errdefer run.deinit();

    var buf: [32768]u8 = undefined;
    const file = Io.Dir.cwd().openFile(io, RUN_PATH, .{}) catch return run;
    defer file.close(io);
    const n = try file.readPositionalAll(io, &buf, 0);

    var r = BufReader{ .buf = buf[0..n] };
    var magic: [4]u8 = undefined;
    try r.readNoEof(&magic);
    if (!std.mem.eql(u8, &magic, &RUN_MAGIC)) return SaveError.InvalidMagic;
    const version = try r.readInt(u32, .little);
    if (version != SAVE_VERSION) return SaveError.SaveVersionMismatch;

    run.run_seed = try r.readInt(u64, .little);
    var rng_s: [4]u64 = undefined;
    for (&rng_s) |*s| s.* = try r.readInt(u64, .little);
    run.rng.setState(rng_s);
    run.current_floor = try r.readInt(u32, .little);
    run.turn_count = try r.readInt(u64, .little);
    run.kills = try r.readInt(u32, .little);
    run.items_found = try r.readInt(u32, .little);
    run.alert_level = try r.readInt(u8, .little);

    run.player.position.x = try r.readInt(i32, .little);
    run.player.position.y = try r.readInt(i32, .little);
    run.player.glyph = try r.readInt(u8, .little);
    run.player.hp = try r.readInt(i32, .little);
    run.player.max_hp = try r.readInt(i32, .little);
    run.player.armor = try r.readInt(u32, .little);
    run.player.evasion = try r.readInt(u32, .little);
    run.player.inventory.count = try r.readInt(u32, .little);
    for (&run.player.inventory.items) |*slot| {
        const v = try r.readInt(u32, .little);
        slot.* = if (v != 0) ids_mod.ItemId{ .value = v } else null;
    }
    for (&run.player.inventory.equipment.slots) |*slot| {
        const v = try r.readInt(u32, .little);
        slot.* = if (v != 0) ids_mod.ItemId{ .value = v } else null;
    }

    const actor_count = try r.readInt(u32, .little);
    run.actors = actor_store_mod.ActorStore.init();
    for (0..actor_count) |_| {
        var e: enemy_mod.Enemy = .{
            .position = .{
                .x = try r.readInt(i32, .little),
                .y = try r.readInt(i32, .little),
            },
        };
        e.glyph = try r.readInt(u8, .little);
        var name_buf: [16]u8 = undefined;
        try r.readNoEof(&name_buf);
        e.name = glyphToName(e.glyph);
        e.alive = (try r.readInt(u8, .little)) != 0;
        e.hp = try r.readInt(i32, .little);
        e.max_hp = try r.readInt(i32, .little);
        e.armor = try r.readInt(u32, .little);
        e.accuracy = try r.readInt(u32, .little);
        e.evasion = try r.readInt(u32, .little);
        e.speed = try r.readInt(u32, .little);
        e.faction = ids_mod.FactionId{ .value = try r.readInt(u32, .little) };
        e.awareness = try r.readInt(u32, .little);
        e.ai.mode = @enumFromInt(try r.readInt(u8, .little));
        e.ai.last_seen_player_x = try r.readInt(i32, .little);
        e.ai.last_seen_player_y = try r.readInt(i32, .little);
        e.ai.turns_since_saw_player = try r.readInt(u32, .little);
        try r.readNoEof(&e.status.durations);
        _ = run.actors.addEnemy(e);
    }

    const item_count = try r.readInt(u32, .little);
    run.items = item_store_mod.ItemStore.init();
    var max_item_id: u32 = 0;
    for (0..item_count) |i| {
        const id_val = try r.readInt(u32, .little);
        run.items.instances[i] = .{
            .id = ids_mod.ItemId{ .value = id_val },
            .def_id = try r.readInt(u16, .little),
            .x = try r.readInt(i32, .little),
            .y = try r.readInt(i32, .little),
            .owner = ids_mod.ActorId{ .value = try r.readInt(u32, .little) },
            .charges = try r.readInt(u32, .little),
            .condition = try r.readInt(u8, .little),
            .quirks = @bitCast(try r.readInt(u8, .little)),
            .identified = (try r.readInt(u8, .little)) != 0,
        };
        if (id_val > max_item_id) max_item_id = id_val;
    }
    run.items.count = item_count;
    run.items.next_id = max_item_id + 1;

    const object_count = try r.readInt(u32, .little);
    run.objects = object_store_mod.ObjectStore.init();
    var max_obj_id: u32 = 0;
    for (0..object_count) |i| {
        const id_val = try r.readInt(u32, .little);
        run.objects.objects[i] = .{
            .id = ids_mod.ObjectId{ .value = id_val },
            .x = try r.readInt(i32, .little),
            .y = try r.readInt(i32, .little),
            .kind = @enumFromInt(try r.readInt(u8, .little)),
            .state = @enumFromInt(try r.readInt(u8, .little)),
            .powered = (try r.readInt(u8, .little)) != 0,
            .difficulty = try r.readInt(u8, .little),
            .alive = (try r.readInt(u8, .little)) != 0,
            .facing = try r.readInt(u8, .little),
        };
        if (id_val > max_obj_id) max_obj_id = id_val;
    }
    run.objects.count = object_count;
    run.objects.next_id = max_obj_id + 1;

    const sched_count = try r.readInt(u32, .little);
    run.scheduler = energy_sched_mod.EnergyScheduler.init();
    for (0..sched_count) |i| {
        run.scheduler.actors[i] = .{
            .id = ids_mod.ActorId{ .value = try r.readInt(u32, .little) },
            .energy = try r.readInt(i32, .little),
            .speed = try r.readInt(u32, .little),
        };
    }
    run.scheduler.count = sched_count;

    const tile_count = try r.readInt(u32, .little);
    _ = tile_count;
    for (0..config.map_height) |y| {
        for (0..config.map_width) |x| {
            run.map.set(@intCast(x), @intCast(y), decodeTile(try r.readInt(u8, .little)));
        }
    }

    run.recomputeFov();
    return run;
}

// ---------------------------------------------------------------------------
// Replay log header
// ---------------------------------------------------------------------------

pub fn saveReplayHeader(io: Io, initial_seed: u64) !void {
    ensureSaveDir(io);
    var buf: [20]u8 = undefined;
    var w = BufWriter{ .buf = &buf };
    try w.writeAll(&REPLAY_MAGIC);
    try w.writeInt(u32, SAVE_VERSION, .little);
    try w.writeInt(u64, initial_seed, .little);
    try w.writeInt(u32, 0, .little);
    try writeAtomic(io, REPLAY_PATH, w.getWritten());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "SAVE_VERSION is 1" {
    try std.testing.expectEqual(@as(u32, 1), SAVE_VERSION);
}

test "encodeTile / decodeTile round-trip" {
    const cases = [_]tile_mod.Tile{
        tile_mod.Tile.wall(),
        tile_mod.Tile.floor(),
        tile_mod.Tile.door_closed(),
        tile_mod.Tile.door_open(),
    };
    for (cases) |tile| {
        const decoded = decodeTile(encodeTile(tile));
        try std.testing.expectEqual(tile.kind, decoded.kind);
        try std.testing.expectEqual(tile.blocks_sight, decoded.blocks_sight);
    }
}

test "bitset32 round-trip" {
    var bs = std.bit_set.StaticBitSet(32).initEmpty();
    bs.set(0);
    bs.set(7);
    bs.set(31);
    const v = bitset32ToU32(&bs);
    const bs2 = u32ToBitset32(v);
    try std.testing.expect(bs2.isSet(0));
    try std.testing.expect(bs2.isSet(7));
    try std.testing.expect(bs2.isSet(31));
    try std.testing.expect(!bs2.isSet(1));
}

test "campaign encode/decode round-trip (in-memory)" {
    var campaign = campaign_mod.CampaignState.init();
    campaign.runs_completed = 3;
    campaign.best_floor = 4;
    campaign.best_score = 350;
    campaign.unlockItem(2);
    campaign.unlockBackground(.ex_military);
    campaign.seeEnemyGlyph('g');
    campaign.discoverLore(5);
    campaign.setWingStatus(.beta_sector, .available);

    var enc: [8192]u8 = undefined;
    var w = BufWriter{ .buf = &enc };
    try w.writeAll(&CAMPAIGN_MAGIC);
    try w.writeInt(u32, SAVE_VERSION, .little);
    try w.writeInt(u32, bitset32ToU32(&campaign.unlocked_items), .little);
    try w.writeInt(u8, bitsetNToU8(&campaign.unlocked_backgrounds, campaign_mod.BACKGROUND_COUNT), .little);
    try w.writeInt(u32, bitset32ToU32(&campaign.seen_item_defs), .little);
    try w.writeInt(u32, bitset32ToU32(&campaign.discovered_lore), .little);
    var glo: u64 = 0;
    var ghi: u64 = 0;
    for (0..64) |i| { if (campaign.seen_enemy_glyphs.isSet(i)) glo = glo | (@as(u64, 1) << @intCast(i)); }
    for (64..128) |i| { if (campaign.seen_enemy_glyphs.isSet(i)) ghi = ghi | (@as(u64, 1) << @intCast(i - 64)); }
    try w.writeInt(u64, glo, .little);
    try w.writeInt(u64, ghi, .little);
    try w.writeInt(u32, campaign.runs_completed, .little);
    try w.writeInt(u32, campaign.runs_failed, .little);
    try w.writeInt(u32, campaign.best_floor, .little);
    try w.writeInt(u32, campaign.best_score, .little);
    try w.writeInt(u32, campaign.total_kills, .little);
    try w.writeInt(u32, campaign.completed_objectives, .little);
    try w.writeInt(u32, @intCast(campaign.history_count), .little);
    try w.writeInt(u32, @intCast(campaign.history_next), .little);
    for (campaign.run_history) |rec| {
        try w.writeInt(u8, @intFromEnum(rec.outcome), .little);
        try w.writeInt(u32, rec.floor, .little);
        try w.writeInt(u32, rec.score, .little);
        try w.writeInt(u64, rec.turn_count, .little);
        try w.writeInt(u32, rec.kills, .little);
        try w.writeInt(u32, rec.items_found, .little);
    }
    for (campaign.wing_status) |ws| try w.writeInt(u8, @intFromEnum(ws), .little);

    var r = BufReader{ .buf = w.getWritten() };
    var magic: [4]u8 = undefined;
    try r.readNoEof(&magic);
    try std.testing.expect(std.mem.eql(u8, &magic, &CAMPAIGN_MAGIC));
    try std.testing.expectEqual(SAVE_VERSION, try r.readInt(u32, .little));
    const loaded_items = u32ToBitset32(try r.readInt(u32, .little));
    try std.testing.expect(loaded_items.isSet(2));
    try std.testing.expect(!loaded_items.isSet(0));
}

test "version mismatch detected" {
    var buf: [16]u8 = undefined;
    var w = BufWriter{ .buf = &buf };
    try w.writeAll(&CAMPAIGN_MAGIC);
    try w.writeInt(u32, SAVE_VERSION + 1, .little);

    var r = BufReader{ .buf = w.getWritten() };
    var magic: [4]u8 = undefined;
    try r.readNoEof(&magic);
    const ver = try r.readInt(u32, .little);
    const err: anyerror = if (ver != SAVE_VERSION) SaveError.SaveVersionMismatch else error.Unexpected;
    try std.testing.expectEqual(SaveError.SaveVersionMismatch, err);
}

test "glyphToName covers known enemies" {
    try std.testing.expectEqualStrings("guard", glyphToName('g'));
    try std.testing.expectEqualStrings("sentinel", glyphToName('s'));
    try std.testing.expectEqualStrings("rogue", glyphToName('r'));
    try std.testing.expectEqualStrings("enforcer", glyphToName('e'));
    try std.testing.expectEqualStrings("unknown", glyphToName('?'));
}

test "CommandByte enum values are stable" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(CommandByte.none));
    try std.testing.expectEqual(@as(u8, 9), @intFromEnum(CommandByte.wait));
    try std.testing.expectEqual(@as(u8, 12), @intFromEnum(CommandByte.hack));
}
