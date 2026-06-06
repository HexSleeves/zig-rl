const std = @import("std");

/// A set of seeds for different scopes of randomness, enabling deterministic
/// replay and independent reproducibility at each game layer.
pub const SeedSet = struct {
    campaign_seed: u64,
    run_seed: u64,
    floor_seed: u64,
    replay_seed: u64,
};

/// Deterministic RNG wrapper around std.Random.DefaultPrng (Xoshiro256++).
/// Explicit seed ownership ensures the same seed always produces the same sequence.
pub const Rng = struct {
    prng: std.Random.DefaultPrng,

    /// Initialize an Rng with an explicit seed.
    pub fn init(seed: u64) Rng {
        return .{ .prng = std.Random.DefaultPrng.init(seed) };
    }

    /// Returns the std.Random interface for use with stdlib random functions.
    pub fn random(self: *Rng) std.Random {
        return self.prng.random();
    }

    /// Returns the next raw u64 from the sequence.
    pub fn next(self: *Rng) u64 {
        return self.prng.next();
    }

    /// Returns a random value of type T in [0, max).
    pub fn nextBounded(self: *Rng, comptime T: type, max: T) T {
        return self.random().uintLessThan(T, max);
    }

    /// Returns a random value of type T in [min, max). Handles both signed and unsigned T.
    pub fn nextRange(self: *Rng, comptime T: type, min: T, max: T) T {
        return self.random().intRangeLessThan(T, min, max);
    }

    /// Returns internal Xoshiro256++ state for serialization.
    pub fn getState(self: *const Rng) [4]u64 {
        return self.prng.s;
    }

    /// Restores internal state from a saved snapshot.
    pub fn setState(self: *Rng, state: [4]u64) void {
        self.prng.s = state;
    }
};

// ── Tests ─────────────────────────────────────────────────────────────────────

test "same seed produces same sequence" {
    var r1 = Rng.init(42);
    const a1 = r1.next();
    const a2 = r1.next();
    const a3 = r1.next();

    var r2 = Rng.init(42);
    const b1 = r2.next();
    const b2 = r2.next();
    const b3 = r2.next();

    try std.testing.expectEqual(a1, b1);
    try std.testing.expectEqual(a2, b2);
    try std.testing.expectEqual(a3, b3);
}

test "different seeds produce different values" {
    var r42 = Rng.init(42);
    var r99 = Rng.init(99);
    try std.testing.expect(r42.next() != r99.next());
}

test "nextRange returns value in [min, max)" {
    var r = Rng.init(12345);
    for (0..1000) |_| {
        const v = r.nextRange(u32, 10, 20);
        try std.testing.expect(v >= 10);
        try std.testing.expect(v < 20);
    }
}

test "SeedSet can be created with explicit values" {
    const seeds = SeedSet{
        .campaign_seed = 111,
        .run_seed = 222,
        .floor_seed = 333,
        .replay_seed = 444,
    };
    try std.testing.expectEqual(@as(u64, 111), seeds.campaign_seed);
    try std.testing.expectEqual(@as(u64, 222), seeds.run_seed);
    try std.testing.expectEqual(@as(u64, 333), seeds.floor_seed);
    try std.testing.expectEqual(@as(u64, 444), seeds.replay_seed);
}
