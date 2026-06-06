const std = @import("std");
const procgen = @import("../world/procgen.zig");
const rng_mod = @import("../rng.zig");
const item_def = @import("item_def.zig");

/// Returns a def_id to spawn for the given zone and floor, or null if nothing spawns.
pub fn rollLoot(zone: procgen.ZoneType, floor: u32, rng: *rng_mod.Rng) ?u16 {
    _ = floor; // future: scale quality by floor
    // 60% chance to spawn something
    if (rng.nextBounded(u32, 10) >= 6) return null;
    return switch (zone) {
        .security    => pickFrom(rng, &[_]u16{ 0, 1, 8 }),      // knives, batons, keycards
        .habitation  => pickFrom(rng, &[_]u16{ 6, 7, 17 }),     // medkits, stims, scrap
        .labs        => pickFrom(rng, &[_]u16{ 14, 15, 12, 16 }), // implants, hacking, data
        .reactor     => pickFrom(rng, &[_]u16{ 5, 13, 17 }),    // heavy armor, repair, scrap
        .cargo       => pickFrom(rng, &[_]u16{ 2, 3, 10, 11 }), // guns, ammo
        .medbay      => pickFrom(rng, &[_]u16{ 6, 6, 7, 13 }), // medkits (weighted), repair
        .data_core   => pickFrom(rng, &[_]u16{ 12, 16, 9 }),    // hacking, data, lab card
        .maintenance => pickFrom(rng, &[_]u16{ 17, 1, 7 }),     // scrap, baton, stim
    };
}

fn pickFrom(rng: *rng_mod.Rng, pool: []const u16) u16 {
    return pool[rng.nextBounded(usize, pool.len)];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "rollLoot returns valid def_id or null" {
    var rng = rng_mod.Rng.init(42);
    for (0..100) |_| {
        const result = rollLoot(.habitation, 1, &rng);
        if (result) |id| {
            try std.testing.expect(item_def.getById(id) != null);
        }
    }
}

test "rollLoot same seed same result" {
    var rng1 = rng_mod.Rng.init(999);
    var rng2 = rng_mod.Rng.init(999);
    const r1 = rollLoot(.security, 1, &rng1);
    const r2 = rollLoot(.security, 1, &rng2);
    try std.testing.expectEqual(r1, r2);
}

test "rollLoot covers all zone types" {
    const zones = [_]procgen.ZoneType{
        .security, .habitation, .labs, .reactor,
        .cargo, .medbay, .data_core, .maintenance,
    };
    for (zones) |zone| {
        var rng = rng_mod.Rng.init(12345);
        // Roll many times; at least one should return non-null for each zone
        var got_item = false;
        for (0..20) |_| {
            if (rollLoot(zone, 1, &rng)) |_| {
                got_item = true;
                break;
            }
        }
        try std.testing.expect(got_item);
    }
}
