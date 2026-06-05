const std = @import("std");
const ids = @import("../ids.zig");
const config = @import("../config.zig");

pub const max_items: usize = 64;

/// Fixed-capacity store for items. Stub for Milestone 5.
pub const ItemStore = struct {
    count: usize,

    /// Create an empty ItemStore.
    pub fn init() ItemStore {
        return ItemStore{ .count = 0 };
    }

    /// Number of items currently stored.
    pub fn itemCount(self: *const ItemStore) usize {
        return self.count;
    }

    // More methods will be added in Milestone 5
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "ItemStore init creates empty store" {
    const store = ItemStore.init();
    try std.testing.expectEqual(@as(usize, 0), store.itemCount());
}
