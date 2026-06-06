const std = @import("std");
const config = @import("../config.zig");
const map_mod = @import("map.zig");
const tile = @import("tile.zig");
const rng_mod = @import("../rng.zig");

pub const ZoneType = enum(u8) {
    habitation = 0,
    labs = 1,
    reactor = 2,
    security = 3,
    cargo = 4,
    medbay = 5,
    data_core = 6,
    maintenance = 7,
};

pub const RoomFlags = packed struct(u8) {
    combat: bool = false,
    loot: bool = false,
    objective: bool = false,
    hazard: bool = false,
    terminal: bool = false,
    safe: bool = false,
    ambush: bool = false,
    vault: bool = false,
};

pub const SpawnKind = enum { player, enemy, objective, exit };

pub const SpawnPoint = struct {
    x: i32,
    y: i32,
    kind: SpawnKind,
};

pub const Room = struct {
    x: usize,
    y: usize,
    w: usize,
    h: usize,
    zone: ZoneType,
    flags: RoomFlags,

    pub fn centerX(self: Room) usize {
        return self.x + self.w / 2;
    }

    pub fn centerY(self: Room) usize {
        return self.y + self.h / 2;
    }

    pub fn contains(self: Room, px: usize, py: usize) bool {
        return px >= self.x and px < self.x + self.w and py >= self.y and py < self.y + self.h;
    }

    /// True if the two rooms overlap including a 1-tile margin.
    pub fn intersects(self: Room, other: Room) bool {
        return (self.x + self.w + 1 > other.x) and
            (other.x + other.w + 1 > self.x) and
            (self.y + self.h + 1 > other.y) and
            (other.y + other.h + 1 > self.y);
    }
};

pub const max_rooms: usize = 8;
pub const max_spawns: usize = 16;

pub const GeneratedFloor = struct {
    map: map_mod.Map,
    rooms: [max_rooms]Room,
    room_count: usize,
    spawns: [max_spawns]SpawnPoint,
    spawn_count: usize,
    door_positions: [max_rooms]struct { x: usize, y: usize },
    door_count: usize,
    terminal_positions: [max_rooms]struct { x: usize, y: usize },
    terminal_count: usize,
    camera_positions: [max_rooms]struct { x: usize, y: usize, facing: u8 },
    camera_count: usize,
};

const min_room_w: usize = 4;
const min_room_h: usize = 3;
const max_room_w: usize = 10;
const max_room_h: usize = 7;
const place_attempts: usize = 60;
const target_rooms: usize = 6;

const zone_cycle = [_]ZoneType{
    .security, .habitation, .labs, .maintenance,
    .cargo,    .medbay,     .reactor, .data_core,
};

pub fn generate(rng: *rng_mod.Rng, floor_num: u32) GeneratedFloor {
    var result = GeneratedFloor{
        .map = map_mod.Map.filled(tile.Tile.wall()),
        .rooms = undefined,
        .room_count = 0,
        .spawns = undefined,
        .spawn_count = 0,
        .door_positions = undefined,
        .door_count = 0,
        .terminal_positions = undefined,
        .terminal_count = 0,
        .camera_positions = undefined,
        .camera_count = 0,
    };

    // Place rooms
    var attempts: usize = 0;
    while (result.room_count < target_rooms and attempts < place_attempts) : (attempts += 1) {
        const w = min_room_w + rng.nextBounded(usize, max_room_w - min_room_w + 1);
        const h = min_room_h + rng.nextBounded(usize, max_room_h - min_room_h + 1);
        if (w + 3 > config.map_width or h + 3 > config.map_height) continue;
        const x = 1 + rng.nextBounded(usize, config.map_width - w - 2);
        const y = 1 + rng.nextBounded(usize, config.map_height - h - 2);
        const candidate = Room{ .x = x, .y = y, .w = w, .h = h, .zone = .habitation, .flags = .{} };

        var overlaps = false;
        for (result.rooms[0..result.room_count]) |existing| {
            if (candidate.intersects(existing)) {
                overlaps = true;
                break;
            }
        }
        if (!overlaps) {
            result.rooms[result.room_count] = candidate;
            result.room_count += 1;
            digRoom(&result.map, candidate);
        }
    }

    if (result.room_count == 0) {
        const r = Room{ .x = 2, .y = 2, .w = 10, .h = 7, .zone = .habitation, .flags = .{} };
        result.rooms[0] = r;
        result.room_count = 1;
        digRoom(&result.map, r);
    }

    // Sort rooms by center X for corridor chaining
    sortRoomsByX(result.rooms[0..result.room_count]);

    // Connect each room to the next with an L-shaped corridor
    var i: usize = 1;
    while (i < result.room_count) : (i += 1) {
        connectRooms(&result, rng, result.rooms[i - 1], result.rooms[i]);
    }

    // Assign zone types and room flags
    for (result.rooms[0..result.room_count], 0..) |*room, idx| {
        const zone_idx = (floor_num + @as(u32, @intCast(idx))) % zone_cycle.len;
        room.zone = zone_cycle[zone_idx];
        room.flags = flagsForZone(room.zone);
    }

    // Place terminals in terminal rooms, cameras in security/combat rooms
    for (result.rooms[0..result.room_count]) |room| {
        const cx = room.centerX();
        const cy = room.centerY();
        if (room.flags.terminal) {
            if (result.terminal_count < max_rooms) {
                const tx = if (cx + 1 < room.x + room.w) cx + 1 else cx;
                result.terminal_positions[result.terminal_count] = .{ .x = tx, .y = cy };
                result.terminal_count += 1;
            }
        }
        if (room.flags.combat or room.zone == .security) {
            if (result.camera_count < max_rooms) {
                const camx = if (cx > room.x) cx - 1 else cx;
                result.camera_positions[result.camera_count] = .{ .x = camx, .y = cy, .facing = 2 };
                result.camera_count += 1;
            }
        }
    }

    // Player spawn: first room center
    addSpawn(&result, result.rooms[0].centerX(), result.rooms[0].centerY(), .player);

    // Objective/exit: last room
    if (result.room_count > 1) {
        const last = result.rooms[result.room_count - 1];
        addSpawn(&result, last.centerX(), last.centerY(), .objective);
        if (result.room_count > 2) {
            addSpawn(&result, last.centerX() + 1, last.centerY(), .exit);
        }
    }

    // Enemy spawns in combat/ambush rooms, capped at max_enemies
    var enemy_count: usize = 0;
    for (result.rooms[1..result.room_count]) |room| {
        if (enemy_count >= config.max_enemies) break;
        if (room.flags.combat or room.flags.ambush) {
            addSpawn(&result, room.centerX(), room.centerY(), .enemy);
            enemy_count += 1;
        }
    }
    // Fallback: place in middle rooms if no combat rooms triggered
    if (enemy_count == 0 and result.room_count >= 3) {
        const mid = result.rooms[result.room_count / 2];
        addSpawn(&result, mid.centerX(), mid.centerY(), .enemy);
        if (result.room_count >= 5 and config.max_enemies > 1) {
            const mid2 = result.rooms[result.room_count / 2 + 1];
            addSpawn(&result, mid2.centerX(), mid2.centerY(), .enemy);
        }
    }

    return result;
}

fn addSpawn(result: *GeneratedFloor, x: usize, y: usize, kind: SpawnKind) void {
    if (result.spawn_count >= max_spawns) return;
    result.spawns[result.spawn_count] = .{
        .x = @intCast(x),
        .y = @intCast(y),
        .kind = kind,
    };
    result.spawn_count += 1;
}

fn flagsForZone(zone: ZoneType) RoomFlags {
    return switch (zone) {
        .security => .{ .combat = true, .terminal = true },
        .habitation => .{ .safe = true, .loot = true },
        .labs => .{ .terminal = true, .hazard = true },
        .reactor => .{ .hazard = true, .objective = true },
        .cargo => .{ .loot = true, .combat = true },
        .medbay => .{ .safe = true, .loot = true },
        .data_core => .{ .terminal = true, .objective = true, .vault = true },
        .maintenance => .{ .ambush = true },
    };
}

fn digRoom(map: *map_mod.Map, room: Room) void {
    var y = room.y;
    while (y < room.y + room.h) : (y += 1) {
        var x = room.x;
        while (x < room.x + room.w) : (x += 1) {
            map.set(x, y, tile.Tile.floor());
        }
    }
}

fn connectRooms(result: *GeneratedFloor, rng: *rng_mod.Rng, a: Room, b: Room) void {
    const ax = a.centerX();
    const ay = a.centerY();
    const bx = b.centerX();
    const by = b.centerY();
    var elbow_x: usize = 0;
    var elbow_y: usize = 0;
    if (rng.nextBounded(u32, 2) == 0) {
        digHorizontalTunnel(&result.map, ax, bx, ay);
        digVerticalTunnel(&result.map, ay, by, bx);
        elbow_x = bx;
        elbow_y = ay;
    } else {
        digVerticalTunnel(&result.map, ay, by, ax);
        digHorizontalTunnel(&result.map, ax, bx, by);
        elbow_x = ax;
        elbow_y = by;
    }
    // Place door at elbow if it's a floor tile and not a room center
    const not_a_center = !a.contains(elbow_x, elbow_y) and !b.contains(elbow_x, elbow_y);
    if (not_a_center and result.door_count < max_rooms) {
        result.door_positions[result.door_count] = .{ .x = elbow_x, .y = elbow_y };
        result.door_count += 1;
    }
}

fn digHorizontalTunnel(map: *map_mod.Map, x1: usize, x2: usize, y: usize) void {
    const start = @min(x1, x2);
    const end = @max(x1, x2);
    var x = start;
    while (x <= end) : (x += 1) map.set(x, y, tile.Tile.floor());
}

fn digVerticalTunnel(map: *map_mod.Map, y1: usize, y2: usize, x: usize) void {
    const start = @min(y1, y2);
    const end = @max(y1, y2);
    var y = start;
    while (y <= end) : (y += 1) map.set(x, y, tile.Tile.floor());
}

fn sortRoomsByX(rooms: []Room) void {
    var i: usize = 1;
    while (i < rooms.len) : (i += 1) {
        const key = rooms[i];
        var j = i;
        while (j > 0 and rooms[j - 1].centerX() > key.centerX()) : (j -= 1) {
            rooms[j] = rooms[j - 1];
        }
        rooms[j] = key;
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "generate produces at least one room" {
    var rng = rng_mod.Rng.init(42);
    const floor = generate(&rng, 1);
    try std.testing.expect(floor.room_count >= 1);
}

test "generate has player spawn" {
    var rng = rng_mod.Rng.init(42);
    const floor = generate(&rng, 1);
    var has_player = false;
    for (floor.spawns[0..floor.spawn_count]) |s| {
        if (s.kind == .player) has_player = true;
    }
    try std.testing.expect(has_player);
}

test "all rooms are within map bounds" {
    var rng = rng_mod.Rng.init(99);
    const floor = generate(&rng, 1);
    for (floor.rooms[0..floor.room_count]) |room| {
        try std.testing.expect(room.x + room.w <= config.map_width);
        try std.testing.expect(room.y + room.h <= config.map_height);
    }
}

test "rooms do not overlap (with margin)" {
    var rng = rng_mod.Rng.init(123);
    const floor = generate(&rng, 1);
    var i: usize = 0;
    while (i < floor.room_count) : (i += 1) {
        var j = i + 1;
        while (j < floor.room_count) : (j += 1) {
            try std.testing.expect(!floor.rooms[i].intersects(floor.rooms[j]));
        }
    }
}

test "same seed produces same floor" {
    var rng1 = rng_mod.Rng.init(777);
    var rng2 = rng_mod.Rng.init(777);
    const f1 = generate(&rng1, 1);
    const f2 = generate(&rng2, 1);
    try std.testing.expectEqual(f1.room_count, f2.room_count);
    try std.testing.expectEqual(f1.spawn_count, f2.spawn_count);
    var i: usize = 0;
    while (i < f1.room_count) : (i += 1) {
        try std.testing.expectEqual(f1.rooms[i].x, f2.rooms[i].x);
        try std.testing.expectEqual(f1.rooms[i].y, f2.rooms[i].y);
    }
}

test "player spawn tile is walkable" {
    var rng = rng_mod.Rng.init(42);
    const floor = generate(&rng, 1);
    for (floor.spawns[0..floor.spawn_count]) |s| {
        if (s.kind == .player) {
            try std.testing.expect(!floor.map.isBlockedAt(s.x, s.y));
        }
    }
}

test "enemy spawns are on walkable tiles" {
    var rng = rng_mod.Rng.init(42);
    const floor = generate(&rng, 1);
    for (floor.spawns[0..floor.spawn_count]) |s| {
        if (s.kind == .enemy) {
            try std.testing.expect(!floor.map.isBlockedAt(s.x, s.y));
        }
    }
}
