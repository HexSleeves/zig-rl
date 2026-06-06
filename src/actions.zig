const std = @import("std");
const movement = @import("systems/movement.zig");
const input = @import("input.zig");
const RunState = @import("run_state.zig").RunState;
const turn = @import("systems/turn.zig");
const combat = @import("systems/combat.zig");
const ids = @import("ids.zig");
const item_def = @import("items/item_def.zig");
const tile_mod = @import("world/tile.zig");
const map_object = @import("world/map_object.zig");

pub const Direction = movement.Direction;

/// Raw intent from input — may be invalid (e.g., move into wall).
pub const ActionIntent = union(enum) {
    move: Direction,
    wait,
    /// Attempt to attack in direction (validated to enemy presence).
    melee_bump: Direction,
    quit,
    pickup,
    use_item: ids.ItemId,
    interact: Direction,
    hack,
};

/// Validated, ready-to-execute form.
pub const Action = union(enum) {
    move: Direction,
    wait,
    melee_bump: Direction,
    quit,
    pickup,
    use_item: ids.ItemId,
    interact: Direction,
    hack,
};

/// Energy costs per action type.
pub const ActionCost = struct {
    pub const move: u32 = 100;
    pub const wait: u32 = 100;
    pub const melee: u32 = 100;
    pub const shoot: u32 = 120;
    pub const reload: u32 = 150;
    pub const hack: u32 = 150;
    pub const heavy: u32 = 200;
};

/// Returns the energy cost of a validated action.
pub fn costOf(action: Action) u32 {
    return switch (action) {
        .move => ActionCost.move,
        .wait => ActionCost.wait,
        .melee_bump => ActionCost.melee,
        .quit => 0,
        .pickup => ActionCost.move,
        .use_item => ActionCost.wait,
        .interact => ActionCost.move,
        .hack => ActionCost.hack,
    };
}

/// Convert an input Command to an ActionIntent.
/// Returns null for .none (no-op inputs).
pub fn intentFromCommand(cmd: input.Command) ?ActionIntent {
    return switch (cmd) {
        .move => |dir| .{ .move = dir },
        .wait => .wait,
        .quit => .quit,
        .pickup => .pickup,
        .hack => .hack,
        .none => null,
    };
}

/// Validate an ActionIntent against the current RunState.
/// Returns a ready-to-execute Action, or null if the action is impossible
/// (e.g. moving into a wall).
pub fn validateIntent(intent: ActionIntent, run: *const RunState) ?Action {
    return switch (intent) {
        .move => |dir| blk: {
            const delta = movement.Direction.delta(dir);
            const new_x = run.player.position.x + delta.x;
            const new_y = run.player.position.y + delta.y;
            if (run.map.isBlockedAt(new_x, new_y)) {
                // If blocked tile is a closed door, interact instead
                const t = run.map.get(@intCast(new_x), @intCast(new_y));
                if (t.kind == .door) break :blk .{ .interact = dir };
                break :blk null;
            }
            // Enemy present at target tile: becomes a melee bump instead
            if (run.actors.glyphAt(new_x, new_y) != null) break :blk .{ .melee_bump = dir };
            break :blk .{ .move = dir };
        },
        .wait => .wait,
        .melee_bump => |dir| .{ .melee_bump = dir },
        .quit => .quit,
        .pickup => .pickup,
        .use_item => |item_id| .{ .use_item = item_id },
        .interact => |dir| .{ .interact = dir },
        .hack => .hack,
    };
}

/// Execute a validated Action against RunState.
/// Quit must be handled at the State level before calling this.
pub fn executeAction(action: Action, run: *RunState) !void {
    switch (action) {
        .move => |dir| {
            _ = try movement.tryMovePlayerRun(run, dir);
            run.recomputeFov();
        },
        .wait => {
            try run.log.add("You wait.");
            try turn.endPlayerTurn(run);
            run.recomputeFov();
        },
        .melee_bump => |dir| {
            const delta = movement.Direction.delta(dir);
            const tx = run.player.position.x + delta.x;
            const ty = run.player.position.y + delta.y;

            if (run.actors.enemyAtPosition(tx, ty)) |target_id| {
                const enemy_name = run.actors.getEnemy(target_id).?.name;
                const result = try combat.playerMeleeAttack(run, target_id);

                if (!result.hit) {
                    var buf: [64]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "You swing at the {s} and miss.", .{enemy_name});
                    try run.log.add(msg);
                } else if (result.is_crit) {
                    var buf: [64]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "Critical hit! You hit the {s} for {d} damage.", .{ enemy_name, result.damage });
                    try run.log.add(msg);
                } else {
                    var buf: [64]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "You hit the {s} for {d} damage.", .{ enemy_name, result.damage });
                    try run.log.add(msg);
                }

                if (result.target_died) {
                    var buf: [64]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "The {s} dies.", .{enemy_name});
                    try run.log.add(msg);
                    run.scheduler.removeActor(target_id);
                    run.kills += 1;
                }
            } else {
                try run.log.add("You swing at nothing.");
            }

            try turn.endPlayerTurn(run);
            run.recomputeFov();
        },
        .interact => |dir| {
            const delta = movement.Direction.delta(dir);
            const tx = run.player.position.x + delta.x;
            const ty = run.player.position.y + delta.y;
            if (run.objects.objectAt(tx, ty)) |obj_id| {
                if (run.objects.getObjectMut(obj_id)) |obj| {
                    if (obj.kind == .door) {
                        if (obj.state == .locked) {
                            try run.log.add("The door is locked. (hack with H)");
                        } else {
                            // open the door
                            obj.state = .open;
                            run.map.set(@intCast(tx), @intCast(ty), tile_mod.Tile.door_open());
                            run.recomputeFov();
                            try run.log.add("You open the door.");
                        }
                    }
                }
            } else {
                // No object — just walk through if tile is now open
                try run.log.add("Nothing to interact with.");
            }
            try turn.endPlayerTurn(run);
            run.recomputeFov();
        },
        .hack => {
            const px = run.player.position.x;
            const py = run.player.position.y;
            // Scan 4 adjacent tiles
            const dirs = [_]struct { dx: i32, dy: i32 }{ .{ .dx = 0, .dy = -1 }, .{ .dx = 0, .dy = 1 }, .{ .dx = -1, .dy = 0 }, .{ .dx = 1, .dy = 0 } };
            var hacked = false;
            for (dirs) |d| {
                const tx = px + d.dx;
                const ty = py + d.dy;
                if (run.objects.objectAt(tx, ty)) |obj_id| {
                    if (run.objects.getObjectMut(obj_id)) |obj| {
                        // Roll vs difficulty
                        const threshold: u32 = @as(u32, obj.difficulty) * 10;
                        const roll = run.rng.nextBounded(u32, 100);
                        if (roll >= threshold) {
                            // Success
                            switch (obj.kind) {
                                .door => {
                                    obj.state = .open;
                                    run.map.set(@intCast(tx), @intCast(ty), tile_mod.Tile.door_open());
                                    run.recomputeFov();
                                    try run.log.add("Door hacked open.");
                                },
                                .terminal => {
                                    obj.state = .hacked;
                                    if (run.alert_level >= 20) {
                                        run.alert_level -= 20;
                                    } else {
                                        run.alert_level = 0;
                                    }
                                    try run.log.add("Terminal hacked. Alert -20.");
                                },
                                .camera => {
                                    obj.state = .disabled;
                                    obj.powered = false;
                                    try run.log.add("Camera disabled.");
                                },
                                else => {
                                    obj.state = .hacked;
                                    try run.log.add("Hack successful.");
                                },
                            }
                        } else {
                            // Fail
                            run.raiseAlert(5);
                            try run.log.add("Hack failed!");
                        }
                        hacked = true;
                        break;
                    }
                }
            }
            if (!hacked) {
                try run.log.add("Nothing to hack.");
            }
            try turn.endPlayerTurn(run);
            run.recomputeFov();
        },
        .quit => {}, // handled at State level
        .pickup => {
            const px = run.player.position.x;
            const py = run.player.position.y;
            if (run.items.firstItemAt(px, py)) |item_id| {
                const inst = run.items.getItemMut(item_id).?;
                const def = item_def.getById(inst.def_id).?;
                if (run.player.inventory.add(item_id)) {
                    // Mark as owned, move off ground
                    inst.owner = ids.player_actor_id;
                    inst.x = -1;
                    inst.y = -1;
                    run.items_found += 1;
                    var buf: [64]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "You pick up the {s}.", .{def.name});
                    try run.log.add(msg);
                } else {
                    try run.log.add("Your inventory is full.");
                }
            } else {
                try run.log.add("There is nothing here to pick up.");
            }
            try turn.endPlayerTurn(run);
            run.recomputeFov();
        },
        .use_item => |item_id| {
            if (run.items.getItemMut(item_id)) |inst| {
                const def = item_def.getById(inst.def_id).?;
                if (def.kind == .consumable) {
                    const heal = def.heal_amount;
                    if (heal > 0) {
                        run.player.hp = @min(run.player.max_hp, run.player.hp + heal);
                    }
                    _ = run.player.inventory.remove(item_id);
                    run.items.removeItem(item_id);
                    var buf: [80]u8 = undefined;
                    const msg = try std.fmt.bufPrint(&buf, "You use the {s}. (+{d} HP)", .{ def.name, heal });
                    try run.log.add(msg);
                } else {
                    try run.log.add("You can't use that.");
                }
            } else {
                try run.log.add("Item not found.");
            }
            try turn.endPlayerTurn(run);
            run.recomputeFov();
        },
    }
}

test "costOf wait" {
    try std.testing.expectEqual(@as(u32, 100), costOf(.wait));
}

test "costOf move north" {
    try std.testing.expectEqual(@as(u32, 100), costOf(.{ .move = .north }));
}

test "costOf melee_bump north" {
    try std.testing.expectEqual(@as(u32, 100), costOf(.{ .melee_bump = .north }));
}

test "ActionCost shoot" {
    try std.testing.expectEqual(@as(u32, 120), ActionCost.shoot);
}

test "ActionCost hack" {
    try std.testing.expectEqual(@as(u32, 150), ActionCost.hack);
}

// ---------------------------------------------------------------------------
// intentFromCommand tests
// ---------------------------------------------------------------------------

test "intentFromCommand returns null for none" {
    try @import("std").testing.expect(intentFromCommand(.none) == null);
}

test "intentFromCommand maps move to intent_move" {
    const intent = intentFromCommand(.{ .move = .north }).?;
    try @import("std").testing.expectEqual(ActionIntent{ .move = .north }, intent);
}

test "intentFromCommand maps wait to intent_wait" {
    const intent = intentFromCommand(.wait).?;
    try @import("std").testing.expectEqual(ActionIntent.wait, intent);
}

// ---------------------------------------------------------------------------
// validateIntent tests
// ---------------------------------------------------------------------------

test "validateIntent: move into wall returns null" {
    var run = try RunState.init(std.testing.allocator);
    defer run.deinit();
    // Player starts at (player_start_x=1, player_start_y=2).
    // Moving west → x=0 which is the boundary wall.
    const result = validateIntent(.{ .move = .west }, &run);
    try std.testing.expect(result == null);
}

test "validateIntent: move into open floor returns move action" {
    var run = try RunState.init(std.testing.allocator);
    defer run.deinit();
    // Player starts at (1, 2). Moving east → (2, 2) is inside room 1..17 x 1..10, open floor.
    const result = validateIntent(.{ .move = .east }, &run);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(Action{ .move = .east }, result.?);
}

test "validateIntent: move into enemy upgrades to melee_bump" {
    var run = try RunState.init(std.testing.allocator);
    defer run.deinit();
    // RunState.init places enemy 1 at (28, 10).
    // Move player to (27, 10), one tile west of that enemy.
    run.player.position = .{ .x = 27, .y = 10 };
    // Moving east from (27,10) → (28,10) where the enemy stands.
    const result = validateIntent(.{ .move = .east }, &run);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(Action{ .melee_bump = .east }, result.?);
}
