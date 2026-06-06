const std = @import("std");
const ids = @import("../ids.zig");
const RunState = @import("../run_state.zig").RunState;

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

    // Player HP not tracked yet (M5) — return result without modifying player
    return MeleeResult{
        .hit = true,
        .damage = final_damage,
        .is_crit = is_crit,
        .target_died = false,
    };
}
