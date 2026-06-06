const map_mod = @import("../world/map.zig");
const movement = @import("../systems/movement.zig");

pub const Direction = movement.Direction;

/// Returns the direction to move one step toward (tx, ty) from (fx, fy).
/// Prefers the cardinal direction with the most progress. Falls back to any valid move.
/// Returns null if no valid move exists.
pub fn stepToward(map: *const map_mod.Map, fx: i32, fy: i32, tx: i32, ty: i32) ?Direction {
    const dx = tx - fx;
    const dy = ty - fy;

    // Build candidate directions ordered by preference (most progress first)
    var candidates: [4]Direction = undefined;
    var count: usize = 0;

    // Primary axis: whichever has greater absolute distance
    if (@abs(dx) >= @abs(dy)) {
        if (dx > 0) { candidates[count] = .east; count += 1; }
        if (dx < 0) { candidates[count] = .west; count += 1; }
        if (dy > 0) { candidates[count] = .south; count += 1; }
        if (dy < 0) { candidates[count] = .north; count += 1; }
    } else {
        if (dy > 0) { candidates[count] = .south; count += 1; }
        if (dy < 0) { candidates[count] = .north; count += 1; }
        if (dx > 0) { candidates[count] = .east; count += 1; }
        if (dx < 0) { candidates[count] = .west; count += 1; }
    }

    // Fill remaining directions as fallback
    const all_dirs = [_]Direction{ .north, .south, .east, .west };
    for (all_dirs) |d| {
        var already = false;
        for (candidates[0..count]) |c| {
            if (c == d) { already = true; break; }
        }
        if (!already) {
            candidates[count] = d;
            count += 1;
        }
    }

    for (candidates[0..count]) |dir| {
        const delta = dir.delta();
        const nx = fx + delta.x;
        const ny = fy + delta.y;
        if (!map.isBlockedAt(nx, ny)) return dir;
    }
    return null;
}

/// Returns the direction to move one step away from (tx, ty) from (fx, fy).
/// Opposite preference to stepToward.
/// Returns null if no valid move exists.
pub fn stepAway(map: *const map_mod.Map, fx: i32, fy: i32, tx: i32, ty: i32) ?Direction {
    const dx = fx - tx; // reversed: away from target
    const dy = fy - ty;

    var candidates: [4]Direction = undefined;
    var count: usize = 0;

    if (@abs(dx) >= @abs(dy)) {
        if (dx > 0) { candidates[count] = .east; count += 1; }
        if (dx < 0) { candidates[count] = .west; count += 1; }
        if (dy > 0) { candidates[count] = .south; count += 1; }
        if (dy < 0) { candidates[count] = .north; count += 1; }
    } else {
        if (dy > 0) { candidates[count] = .south; count += 1; }
        if (dy < 0) { candidates[count] = .north; count += 1; }
        if (dx > 0) { candidates[count] = .east; count += 1; }
        if (dx < 0) { candidates[count] = .west; count += 1; }
    }

    const all_dirs = [_]Direction{ .north, .south, .east, .west };
    for (all_dirs) |d| {
        var already = false;
        for (candidates[0..count]) |c| {
            if (c == d) { already = true; break; }
        }
        if (!already) {
            candidates[count] = d;
            count += 1;
        }
    }

    for (candidates[0..count]) |dir| {
        const delta = dir.delta();
        const nx = fx + delta.x;
        const ny = fy + delta.y;
        if (!map.isBlockedAt(nx, ny)) return dir;
    }
    return null;
}
