const State = @import("../state.zig").State;
const RunState = @import("../run_state.zig").RunState;
const ids = @import("../ids.zig");
const ai_system = @import("../ai/ai_system.zig");
const combat = @import("combat.zig");
const actions = @import("../actions.zig");

const ActionCost = actions.ActionCost;

/// End the player turn using a RunState pointer directly.
pub fn endPlayerTurn(run: *RunState) !void {
    run.turn_count += 1;
    if (run.turn_count == 1) {
        try run.log.add("The dungeon waits.");
    }
}

/// Backward-compat wrapper: end player turn from a full State.
pub fn endPlayerTurnState(state: *State) !void {
    try endPlayerTurn(&state.run);
}

/// Advances an NPC actor's turn via AI decision-making.
/// Returns the energy cost of the action taken.
pub fn endActorTurn(run: *RunState, actor_id: ids.ActorId) !u32 {
    // Get enemy (mutable for position updates and AI state)
    const enemy = run.actors.getEnemyMut(actor_id) orelse return 0;
    if (!enemy.isAlive()) return 0;

    // Decide action via AI
    const action = ai_system.decideAction(run, actor_id, &enemy.ai);

    // Execute action
    const cost: u32 = switch (action) {
        .wait => ActionCost.wait,
        .move => |dir| blk: {
            const delta = dir.delta();
            const nx = enemy.position.x + delta.x;
            const ny = enemy.position.y + delta.y;
            // Moving into player tile → melee instead of occupying
            if (nx == run.player.position.x and ny == run.player.position.y) {
                _ = try combat.enemyMeleeAttack(run, actor_id);
                break :blk ActionCost.melee;
            }
            // Don't stack onto another enemy
            if (!run.map.isBlockedAt(nx, ny) and run.actors.enemyAtPosition(nx, ny) == null) {
                enemy.position.x = nx;
                enemy.position.y = ny;
            }
            break :blk ActionCost.move;
        },
        .melee_attack => blk: {
            // Enemy attacks player
            _ = try combat.enemyMeleeAttack(run, actor_id);
            break :blk ActionCost.melee;
        },
    };

    // Tick status effects (decrements all active durations by 1)
    enemy.status.tick();

    return cost;
}
