const std = @import("std");
const ids = @import("ids.zig");

pub const PLAYER: ids.FactionId = .{ .value = 0 };
pub const SECURITY: ids.FactionId = .{ .value = 1 };
pub const ROGUE_MACHINES: ids.FactionId = .{ .value = 2 };
pub const ESCAPED_EXPERIMENTS: ids.FactionId = .{ .value = 3 };
pub const NEUTRAL: ids.FactionId = .{ .value = 4 };

/// Returns true if faction a is hostile to faction b.
pub fn isHostile(a: ids.FactionId, b: ids.FactionId) bool {
    // Player is hostile to security and rogue machines
    // Security is hostile to player, rogue machines, escaped experiments
    // Rogue machines are hostile to everyone except themselves
    // Escaped experiments are hostile to security and player
    // Neutral never attacks first
    if (a.eql(b)) return false;
    if (a.eql(NEUTRAL) or b.eql(NEUTRAL)) return false;
    if (a.eql(PLAYER)) return b.eql(SECURITY) or b.eql(ROGUE_MACHINES) or b.eql(ESCAPED_EXPERIMENTS);
    if (a.eql(SECURITY)) return b.eql(PLAYER) or b.eql(ROGUE_MACHINES) or b.eql(ESCAPED_EXPERIMENTS);
    if (a.eql(ROGUE_MACHINES)) return !b.eql(ROGUE_MACHINES);
    if (a.eql(ESCAPED_EXPERIMENTS)) return b.eql(PLAYER) or b.eql(SECURITY);
    return false;
}

test "player is hostile to SECURITY" {
    try std.testing.expect(isHostile(PLAYER, SECURITY));
}

test "SECURITY is hostile to ROGUE_MACHINES" {
    try std.testing.expect(isHostile(SECURITY, ROGUE_MACHINES));
}

test "NEUTRAL is never hostile to anyone" {
    try std.testing.expect(!isHostile(NEUTRAL, PLAYER));
    try std.testing.expect(!isHostile(NEUTRAL, SECURITY));
    try std.testing.expect(!isHostile(NEUTRAL, ROGUE_MACHINES));
    try std.testing.expect(!isHostile(NEUTRAL, ESCAPED_EXPERIMENTS));
    try std.testing.expect(!isHostile(PLAYER, NEUTRAL));
    try std.testing.expect(!isHostile(SECURITY, NEUTRAL));
}

test "same faction is never hostile to itself" {
    try std.testing.expect(!isHostile(PLAYER, PLAYER));
    try std.testing.expect(!isHostile(SECURITY, SECURITY));
    try std.testing.expect(!isHostile(ROGUE_MACHINES, ROGUE_MACHINES));
    try std.testing.expect(!isHostile(ESCAPED_EXPERIMENTS, ESCAPED_EXPERIMENTS));
    try std.testing.expect(!isHostile(NEUTRAL, NEUTRAL));
}

test "isHostile is not necessarily symmetric: ROGUE_MACHINES hostile to PLAYER, PLAYER hostile to ROGUE_MACHINES" {
    try std.testing.expect(isHostile(ROGUE_MACHINES, PLAYER));
    try std.testing.expect(isHostile(PLAYER, ROGUE_MACHINES));
}
