const std = @import("std");
const ids = @import("../ids.zig");
const map_mod = @import("../world/map.zig");
const RunState = @import("../run_state.zig").RunState;
const visibility_mod = @import("../visibility.zig");

pub const PLAYER_ACCURACY: u32 = 75;
pub const PLAYER_EVASION: u32 = 15;
pub const PLAYER_BASE_DAMAGE: u32 = 4;

pub const MeleeResult = struct {
    hit: bool,
    damage: u32,
    is_crit: bool,
    target_died: bool,
};

/// Resolve player melee attack against enemy at given ActorId.
pub fn playerMeleeAttack(run: *RunState, target_id: ids.ActorId) !MeleeResult {
    const enemy = run.actors.getEnemyMut(target_id) orelse return MeleeResult{
        .hit = false,
        .damage = 0,
        .is_crit = false,
        .target_died = false,
    };

    const hit_roll = run.rng.nextRange(u32, 0, 100);
    const hit_threshold = if (PLAYER_ACCURACY > enemy.evasion) PLAYER_ACCURACY - enemy.evasion else 0;
    const hits = hit_roll < hit_threshold;
    const is_crit = hit_roll < 5;

    if (!hits and !is_crit) {
        return MeleeResult{ .hit = false, .damage = 0, .is_crit = false, .target_died = false };
    }

    var raw_damage = run.rng.nextRange(u32, 1, 8) + PLAYER_BASE_DAMAGE;
    if (is_crit) raw_damage *= 2;
    const final_damage: u32 = if (raw_damage > enemy.armor) raw_damage - enemy.armor else 1;

    enemy.takeDamage(@intCast(final_damage));
    const died = !enemy.isAlive();

    return MeleeResult{
        .hit = true,
        .damage = final_damage,
        .is_crit = is_crit,
        .target_died = died,
    };
}

/// Returns true if the shared visibility model can see from (x0,y0) to (x1,y1).
pub fn hasLineOfSight(map: *const map_mod.Map, x0: i32, y0: i32, x1: i32, y1: i32) bool {
    return visibility_mod.hasLineOfSight(map, x0, y0, x1, y1);
}

/// Ranged attack from player to target. Requires line of sight.
/// Returns null if no LoS. Uses same damage formula as melee.
/// Energy cost (120) is handled by the caller.
pub fn playerRangedAttack(run: *RunState, target_id: ids.ActorId) !?MeleeResult {
    const enemy = run.actors.getEnemyMut(target_id) orelse return MeleeResult{
        .hit = false,
        .damage = 0,
        .is_crit = false,
        .target_died = false,
    };

    // Check line of sight from player to target
    const px = run.player.position.x;
    const py = run.player.position.y;
    const tx = enemy.position.x;
    const ty = enemy.position.y;

    if (!hasLineOfSight(&run.map, px, py, tx, ty)) return null;

    const hit_roll = run.rng.nextRange(u32, 0, 100);
    const hit_threshold = if (PLAYER_ACCURACY > enemy.evasion) PLAYER_ACCURACY - enemy.evasion else 0;
    const hits = hit_roll < hit_threshold;
    const is_crit = hit_roll < 5;

    if (!hits and !is_crit) {
        return MeleeResult{ .hit = false, .damage = 0, .is_crit = false, .target_died = false };
    }

    var raw_damage = run.rng.nextRange(u32, 1, 8) + PLAYER_BASE_DAMAGE;
    if (is_crit) raw_damage *= 2;
    const final_damage: u32 = if (raw_damage > enemy.armor) raw_damage - enemy.armor else 1;

    enemy.takeDamage(@intCast(final_damage));
    const died = !enemy.isAlive();

    return MeleeResult{
        .hit = true,
        .damage = final_damage,
        .is_crit = is_crit,
        .target_died = died,
    };
}

/// Resolve enemy melee attack against player.
pub fn enemyMeleeAttack(run: *RunState, attacker_id: ids.ActorId) !MeleeResult {
    const enemy = run.actors.getEnemy(attacker_id) orelse return MeleeResult{
        .hit = false,
        .damage = 0,
        .is_crit = false,
        .target_died = false,
    };

    const hit_roll = run.rng.nextRange(u32, 0, 100);
    const hit_threshold = if (enemy.accuracy > PLAYER_EVASION) enemy.accuracy - PLAYER_EVASION else 0;
    const hits = hit_roll < hit_threshold;
    const is_crit = hit_roll < 5;

    if (!hits and !is_crit) {
        return MeleeResult{ .hit = false, .damage = 0, .is_crit = false, .target_died = false };
    }

    const raw_damage = run.rng.nextRange(u32, 1, 8);
    const final_damage: u32 = if (raw_damage > 0) raw_damage else 1;

    // Apply damage to player
    run.player.hp -= @as(i32, @intCast(final_damage));
    if (run.player.hp <= 0) run.player.hp = 0;

    return MeleeResult{
        .hit = true,
        .damage = final_damage,
        .is_crit = is_crit,
        .target_died = false,
    };
}

// --- Tests ---

const testing = std.testing;
const tile_mod = @import("../world/tile.zig");

test "hasLineOfSight: unobstructed path returns true" {
    var map = map_mod.Map.filled(tile_mod.Tile.floor());
    // Straight horizontal line, no walls
    try testing.expect(hasLineOfSight(&map, 0, 0, 5, 0));
    // Diagonal
    try testing.expect(hasLineOfSight(&map, 0, 0, 4, 4));
    // Same tile
    try testing.expect(hasLineOfSight(&map, 3, 3, 3, 3));
}

test "hasLineOfSight: wall in the way returns false" {
    var map = map_mod.Map.filled(tile_mod.Tile.floor());
    // Place a wall at (3, 0) blocking a horizontal line from (0,0) to (6,0)
    map.set(3, 0, tile_mod.Tile.wall());
    try testing.expect(!hasLineOfSight(&map, 0, 0, 6, 0));
}

test "hasLineOfSight: wall at start or end does not block" {
    var map = map_mod.Map.filled(tile_mod.Tile.floor());
    // Wall at start tile — should not block (start is skipped)
    map.set(0, 0, tile_mod.Tile.wall());
    try testing.expect(hasLineOfSight(&map, 0, 0, 5, 0));
    // Wall at end tile — should not block (end is skipped)
    var map2 = map_mod.Map.filled(tile_mod.Tile.floor());
    map2.set(5, 0, tile_mod.Tile.wall());
    try testing.expect(hasLineOfSight(&map2, 0, 0, 5, 0));
}

test "hasLineOfSight: matches visibility map for line-clear target" {
    const lines = [_][]const u8{
        "############",
        "#....#...#.#",
        "#..#.......#",
        "#......##..#",
        "##...#.....#",
        "#.#.#.....##",
        "#...#....#.#",
        "##....#....#",
        "#........###",
        "#.#..#.....#",
        "##....#....#",
        "############",
    };
    var map = mapFromLines(&lines);

    var vm = visibility_mod.VisibilityMap.init();
    vm.compute(&map, 7, 2, 8);

    try testing.expectEqual(vm.isVisible(4, 7), hasLineOfSight(&map, 7, 2, 4, 7));
}

fn mapFromLines(lines: []const []const u8) map_mod.Map {
    var map = map_mod.Map.filled(tile_mod.Tile.floor());
    for (lines, 0..) |line, y| {
        for (line, 0..) |ch, x| {
            if (ch == '#') {
                map.set(x, y, tile_mod.Tile.wall());
            }
        }
    }
    return map;
}
