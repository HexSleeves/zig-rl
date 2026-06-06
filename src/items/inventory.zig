const std = @import("std");
const ids = @import("../ids.zig");

pub const EquipSlot = enum(u8) {
    primary_weapon = 0,
    sidearm = 1,
    armor_rig = 2,
    implant_1 = 3,
    implant_2 = 4,
    utility_1 = 5,
    utility_2 = 6,

    pub const count = 7;
};

pub const Equipment = struct {
    slots: [EquipSlot.count]?ids.ItemId = [_]?ids.ItemId{null} ** EquipSlot.count,

    pub fn get(self: *const Equipment, slot: EquipSlot) ?ids.ItemId {
        return self.slots[@intFromEnum(slot)];
    }

    pub fn put(self: *Equipment, slot: EquipSlot, id: ids.ItemId) ?ids.ItemId {
        const prev = self.slots[@intFromEnum(slot)];
        self.slots[@intFromEnum(slot)] = id;
        return prev;
    }

    pub fn remove(self: *Equipment, slot: EquipSlot) ?ids.ItemId {
        const prev = self.slots[@intFromEnum(slot)];
        self.slots[@intFromEnum(slot)] = null;
        return prev;
    }

    pub fn isEquipped(self: *const Equipment, id: ids.ItemId) bool {
        for (self.slots) |s| {
            if (s) |equipped_id| {
                if (equipped_id.eql(id)) return true;
            }
        }
        return false;
    }
};

pub const max_inventory: usize = 20;

pub const Inventory = struct {
    items: [max_inventory]?ids.ItemId = [_]?ids.ItemId{null} ** max_inventory,
    count: usize = 0,
    equipment: Equipment = .{},

    pub fn add(self: *Inventory, id: ids.ItemId) bool {
        if (self.count >= max_inventory) return false;
        for (&self.items) |*slot| {
            if (slot.* == null) {
                slot.* = id;
                self.count += 1;
                return true;
            }
        }
        return false;
    }

    pub fn remove(self: *Inventory, id: ids.ItemId) bool {
        for (&self.items) |*slot| {
            if (slot.*) |stored| {
                if (stored.eql(id)) {
                    slot.* = null;
                    self.count -= 1;
                    return true;
                }
            }
        }
        return false;
    }

    pub fn has(self: *const Inventory, id: ids.ItemId) bool {
        for (self.items) |slot| {
            if (slot) |stored| {
                if (stored.eql(id)) return true;
            }
        }
        return false;
    }

    pub fn equip(self: *Inventory, id: ids.ItemId, slot: EquipSlot) ?ids.ItemId {
        return self.equipment.put(slot, id);
    }

    pub fn unequip(self: *Inventory, slot: EquipSlot) ?ids.ItemId {
        return self.equipment.remove(slot);
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "Inventory add and remove" {
    var inv = Inventory{};
    const id = ids.ItemId{ .value = 1 };
    try std.testing.expect(inv.add(id));
    try std.testing.expectEqual(@as(usize, 1), inv.count);
    try std.testing.expect(inv.has(id));
    try std.testing.expect(inv.remove(id));
    try std.testing.expectEqual(@as(usize, 0), inv.count);
    try std.testing.expect(!inv.has(id));
}

test "Inventory full returns false" {
    var inv = Inventory{};
    var i: u32 = 0;
    while (i < max_inventory) : (i += 1) {
        try std.testing.expect(inv.add(ids.ItemId{ .value = i }));
    }
    try std.testing.expectEqual(max_inventory, inv.count);
    try std.testing.expect(!inv.add(ids.ItemId{ .value = 99 }));
}

test "Equipment put and remove" {
    var eq = Equipment{};
    const id = ids.ItemId{ .value = 5 };
    _ = eq.put(.primary_weapon, id);
    try std.testing.expect(eq.get(.primary_weapon) != null);
    try std.testing.expect(eq.isEquipped(id));
    _ = eq.remove(.primary_weapon);
    try std.testing.expect(eq.get(.primary_weapon) == null);
}
