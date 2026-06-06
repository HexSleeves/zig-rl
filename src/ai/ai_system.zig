const std = @import("std");
const ids = @import("../ids.zig");
const RunState = @import("../run_state.zig").RunState;
const behavior = @import("behavior.zig");
const pathfind = @import("pathfind.zig");

pub const AiState = behavior.AiState;
pub const AiMode = behavior.AiMode;
pub const Direction = pathfind.Direction;

pub const AiAction = union(enum) {
    move: Direction,
    wait,
    melee_attack: ids.ActorId,
};

/// Chebyshev distance (max of axis deltas) for range checks.
fn chebyshevDist(x1: i32, y1: i32, x2: i32, y2: i32) u32 {
    const dx = @abs(x1 - x2);
    const dy = @abs(y1 - y2);
    return @intCast(@max(dx, dy));
}

/// Simple line-of-sight: walk the primary axis and check for wall blocks.
/// Returns true if there is a clear line between (x1,y1) and (x2,y2).
fn hasLoS(run: *const RunState, x1: i32, y1: i32, x2: i32, y2: i32) bool {
    var cx = x1;
    var cy = y1;
    const dx: i32 = if (x2 > x1) 1 else if (x2 < x1) -1 else 0;
    const dy: i32 = if (y2 > y1) 1 else if (y2 < y1) -1 else 0;
    while (cx != x2 or cy != y2) {
        cx += dx;
        cy += dy;
        if (cx == x2 and cy == y2) break;
        if (run.map.isBlockedAt(cx, cy)) return false;
    }
    return true;
}

/// Pick a random cardinal direction using run.rng.
fn randomDir(run: *RunState) Direction {
    const roll = run.rng.nextBounded(u32, 4);
    return switch (roll) {
        0 => .north,
        1 => .south,
        2 => .east,
        else => .west,
    };
}

/// Decide what action an enemy should take this turn.
/// `run` is const for reads; rng requires mutable access so use a mut cast.
pub fn decideAction(
    run: *RunState,
    enemy_id: ids.ActorId,
    ai_state: *AiState,
) AiAction {
    const enemy = run.actors.getEnemy(enemy_id) orelse return .wait;
    if (!enemy.isAlive()) return .wait;

    const ex = enemy.position.x;
    const ey = enemy.position.y;
    const px = run.player.position.x;
    const py = run.player.position.y;
    const awareness = enemy.awareness;

    const dist = chebyshevDist(ex, ey, px, py);
    const player_visible = dist <= awareness and hasLoS(run, ex, ey, px, py);

    // HP check: switch to flee if below 25%
    const max_hp = enemy.max_hp;
    const cur_hp = enemy.hp;
    if (max_hp > 0 and cur_hp * 4 < max_hp) {
        ai_state.mode = .flee;
    }

    switch (ai_state.mode) {
        .sentry => {
            if (player_visible) {
                return AiAction{ .melee_attack = ids.player_actor_id };
            }
            return .wait;
        },

        .idle => {
            if (player_visible) {
                ai_state.mode = .chase;
                ai_state.last_seen_player_x = px;
                ai_state.last_seen_player_y = py;
                ai_state.turns_since_saw_player = 0;
                // Fall through to chase logic below by recursing one level is fine,
                // but we'll just do the move here directly.
                if (pathfind.stepToward(&run.map, ex, ey, px, py)) |dir| {
                    return AiAction{ .move = dir };
                }
                return .wait;
            }
            return .wait;
        },

        .patrol => {
            if (player_visible) {
                ai_state.mode = .chase;
                ai_state.last_seen_player_x = px;
                ai_state.last_seen_player_y = py;
                ai_state.turns_since_saw_player = 0;
                if (pathfind.stepToward(&run.map, ex, ey, px, py)) |dir| {
                    return AiAction{ .move = dir };
                }
                return .wait;
            }
            // Wander: 75% chance to move, 25% wait
            const roll = run.rng.nextBounded(u32, 4);
            if (roll < 3) {
                const dir = randomDir(run);
                const delta = dir.delta();
                const nx = ex + delta.x;
                const ny = ey + delta.y;
                if (!run.map.isBlockedAt(nx, ny)) {
                    return AiAction{ .move = dir };
                }
            }
            return .wait;
        },

        .chase => {
            if (player_visible) {
                ai_state.last_seen_player_x = px;
                ai_state.last_seen_player_y = py;
                ai_state.turns_since_saw_player = 0;
                if (pathfind.stepToward(&run.map, ex, ey, px, py)) |dir| {
                    return AiAction{ .move = dir };
                }
                return .wait;
            }
            // Lost player
            ai_state.turns_since_saw_player += 1;
            if (ai_state.turns_since_saw_player >= 5) {
                ai_state.mode = .patrol;
                return .wait;
            }
            // Move toward last known position
            const lx = ai_state.last_seen_player_x;
            const ly = ai_state.last_seen_player_y;
            if (pathfind.stepToward(&run.map, ex, ey, lx, ly)) |dir| {
                return AiAction{ .move = dir };
            }
            return .wait;
        },

        .flee => {
            if (pathfind.stepAway(&run.map, ex, ey, px, py)) |dir| {
                return AiAction{ .move = dir };
            }
            return .wait;
        },
    }
}
