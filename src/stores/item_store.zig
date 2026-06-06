const std = @import("std");
const ids = @import("../ids.zig");
const config = @import("../config.zig");
const item_def = @import("../items/item_def.zig");

pub const ItemInstance = struct {
    id: ids.ItemId,
    def_id: u16,
    x: i32, // map position; -1 = in inventory
    y: i32,
    owner: ids.ActorId, // invalid = on ground
    charges: u32,
    condition: u8, // 0-100
    quirks: item_def.ItemQuirks,
    identified: bool,
};

pub const ItemStore = struct {
    instances: [config.max_items]ItemInstance,
    count: usize,
    next_id: u32,

    pub fn init() ItemStore {
        return ItemStore{
            .instances = undefined,
            .count = 0,
            .next_id = 1,
        };
    }

    /// Number of items currently stored.
    pub fn itemCount(self: *const ItemStore) usize {
        return self.count;
    }

    /// Place an item on the ground at (x, y). Returns the new ItemId or null if store is full.
    pub fn addItem(self: *ItemStore, def_id: u16, x: i32, y: i32) ?ids.ItemId {
        if (self.count >= config.max_items) return null;
        const def = item_def.getById(def_id) orelse return null;
        const new_id = ids.ItemId{ .value = self.next_id };
        self.next_id += 1;
        self.instances[self.count] = .{
            .id = new_id,
            .def_id = def_id,
            .x = x,
            .y = y,
            .owner = ids.ActorId.invalid,
            .charges = def.charges,
            .condition = 100,
            .quirks = .{},
            .identified = false,
        };
        self.count += 1;
        return new_id;
    }

    /// Get a const pointer to an item by id, or null if not found.
    pub fn getItem(self: *const ItemStore, id: ids.ItemId) ?*const ItemInstance {
        for (self.instances[0..self.count]) |*inst| {
            if (inst.id.eql(id)) return inst;
        }
        return null;
    }

    /// Get a mutable pointer to an item by id, or null if not found.
    pub fn getItemMut(self: *ItemStore, id: ids.ItemId) ?*ItemInstance {
        for (self.instances[0..self.count]) |*inst| {
            if (inst.id.eql(id)) return inst;
        }
        return null;
    }

    /// Remove an item from the store by id. No-op if not found.
    pub fn removeItem(self: *ItemStore, id: ids.ItemId) void {
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.instances[i].id.eql(id)) {
                // Swap with last
                self.instances[i] = self.instances[self.count - 1];
                self.count -= 1;
                return;
            }
        }
    }

    /// Count of items at position (x, y) on the ground.
    pub fn itemsAtPositionCount(self: *const ItemStore, x: i32, y: i32) usize {
        var n: usize = 0;
        for (self.instances[0..self.count]) |*inst| {
            if (inst.x == x and inst.y == y and !inst.owner.isValid()) n += 1;
        }
        return n;
    }

    /// Returns the id of the first item at position (x, y) on the ground, or null.
    pub fn firstItemAt(self: *const ItemStore, x: i32, y: i32) ?ids.ItemId {
        for (self.instances[0..self.count]) |*inst| {
            if (inst.x == x and inst.y == y and !inst.owner.isValid()) return inst.id;
        }
        return null;
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "ItemStore init creates empty store" {
    const store = ItemStore.init();
    try std.testing.expectEqual(@as(usize, 0), store.itemCount());
}

test "ItemStore addItem places item on ground" {
    var store = ItemStore.init();
    const id = store.addItem(6, 5, 10); // medkit at (5,10)
    try std.testing.expect(id != null);
    try std.testing.expectEqual(@as(usize, 1), store.itemCount());
    const inst = store.getItem(id.?).?;
    try std.testing.expectEqual(@as(u16, 6), inst.def_id);
    try std.testing.expectEqual(@as(i32, 5), inst.x);
    try std.testing.expectEqual(@as(i32, 10), inst.y);
    try std.testing.expect(!inst.owner.isValid());
}

test "ItemStore getItem returns null for unknown id" {
    var store = ItemStore.init();
    const fake = ids.ItemId{ .value = 999 };
    try std.testing.expect(store.getItem(fake) == null);
}

test "ItemStore removeItem removes item" {
    var store = ItemStore.init();
    const id = store.addItem(0, 1, 1).?;
    store.removeItem(id);
    try std.testing.expectEqual(@as(usize, 0), store.itemCount());
    try std.testing.expect(store.getItem(id) == null);
}

test "ItemStore firstItemAt finds ground item" {
    var store = ItemStore.init();
    const id = store.addItem(7, 3, 4).?; // stim pack
    try std.testing.expect(store.firstItemAt(3, 4) != null);
    try std.testing.expect(store.firstItemAt(3, 4).?.eql(id));
    try std.testing.expect(store.firstItemAt(0, 0) == null);
}
