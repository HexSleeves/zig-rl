const std = @import("std");

pub const ItemKind = enum(u8) {
    weapon,
    ammo,
    armor,
    implant,
    tool,
    consumable,
    keycard,
    quest_data,
    crafting_part,
};

pub const ItemQuirks = packed struct(u8) {
    unstable_prototype: bool = false,
    illegal_firmware: bool = false,
    compromised: bool = false,
    battery_drain: bool = false,
    noisy: bool = false,
    emp_sensitive: bool = false,
    _pad: u2 = 0,
};

pub const ItemDef = struct {
    id: u16,
    name: []const u8,
    glyph: u8,
    kind: ItemKind,
    // Weapon
    damage_min: i32 = 0,
    damage_max: i32 = 0,
    accuracy_bonus: i32 = 0,
    range: u32 = 1,
    mag_size: u32 = 0,
    // Armor / implant
    armor_bonus: u32 = 0,
    evasion_bonus: i32 = 0,
    evasion_penalty: i32 = 0,
    // Consumable / tool
    heal_amount: i32 = 0,
    charges: u32 = 0,
    // General
    value: u32 = 1,
    stack_max: u32 = 1,
};

pub const ITEM_DEFS = [_]ItemDef{
    // ── Weapons ────────────────────────────────────────────────────────────
    .{ .id = 0,  .name = "combat knife",    .glyph = '/', .kind = .weapon,   .damage_min = 3, .damage_max = 6,  .accuracy_bonus = 5,   .range = 1, .value = 15 },
    .{ .id = 1,  .name = "stun baton",      .glyph = '|', .kind = .weapon,   .damage_min = 2, .damage_max = 4,  .accuracy_bonus = 10,  .range = 1, .value = 12 },
    .{ .id = 2,  .name = "pistol",          .glyph = 'p', .kind = .weapon,   .damage_min = 4, .damage_max = 8,  .accuracy_bonus = 0,   .range = 8,  .mag_size = 12, .value = 40 },
    .{ .id = 3,  .name = "shotgun",         .glyph = 'P', .kind = .weapon,   .damage_min = 8, .damage_max = 14, .accuracy_bonus = -10, .range = 4,  .mag_size = 6,  .value = 60 },
    // ── Armor ──────────────────────────────────────────────────────────────
    .{ .id = 4,  .name = "tactical vest",   .glyph = '[', .kind = .armor,    .armor_bonus = 2, .evasion_penalty = 0,   .value = 30 },
    .{ .id = 5,  .name = "heavy plating",   .glyph = '[', .kind = .armor,    .armor_bonus = 5, .evasion_penalty = -10, .value = 70 },
    // ── Consumables ────────────────────────────────────────────────────────
    .{ .id = 6,  .name = "medkit",          .glyph = '+', .kind = .consumable, .heal_amount = 8,  .value = 20 },
    .{ .id = 7,  .name = "stim pack",       .glyph = '+', .kind = .consumable, .heal_amount = 3,  .value = 8 },
    // ── Keycards ───────────────────────────────────────────────────────────
    .{ .id = 8,  .name = "security card",   .glyph = 'k', .kind = .keycard,  .value = 5 },
    .{ .id = 9,  .name = "lab access card", .glyph = 'k', .kind = .keycard,  .value = 5 },
    // ── Ammo ───────────────────────────────────────────────────────────────
    .{ .id = 10, .name = "pistol ammo",     .glyph = '.', .kind = .ammo,     .stack_max = 50, .value = 1 },
    .{ .id = 11, .name = "shotgun shells",  .glyph = '.', .kind = .ammo,     .stack_max = 30, .value = 2 },
    // ── Tools ──────────────────────────────────────────────────────────────
    .{ .id = 12, .name = "hacking tool",    .glyph = 't', .kind = .tool,     .charges = 5, .value = 25 },
    .{ .id = 13, .name = "repair kit",      .glyph = 't', .kind = .tool,     .charges = 3, .heal_amount = 5, .value = 15 },
    // ── Implants ───────────────────────────────────────────────────────────
    .{ .id = 14, .name = "reflex implant",  .glyph = '*', .kind = .implant,  .evasion_bonus = 10, .value = 80 },
    .{ .id = 15, .name = "subdermal plates",.glyph = '*', .kind = .implant,  .armor_bonus = 1, .value = 90 },
    // ── Quest / crafting ──────────────────────────────────────────────────
    .{ .id = 16, .name = "data chip",       .glyph = 'd', .kind = .quest_data, .value = 50 },
    .{ .id = 17, .name = "scrap metal",     .glyph = ',', .kind = .crafting_part, .stack_max = 10, .value = 2 },
};

pub const ITEM_DEF_COUNT = ITEM_DEFS.len;

pub fn getById(id: u16) ?*const ItemDef {
    for (&ITEM_DEFS) |*def| {
        if (def.id == id) return def;
    }
    return null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "all item def ids are unique" {
    var seen = std.bit_set.StaticBitSet(256).initEmpty();
    for (ITEM_DEFS) |def| {
        try std.testing.expect(!seen.isSet(def.id));
        seen.set(def.id);
    }
}

test "getById returns correct def" {
    const def = getById(6).?;
    try std.testing.expectEqualStrings("medkit", def.name);
    try std.testing.expectEqual(@as(i32, 8), def.heal_amount);
}

test "getById returns null for unknown id" {
    try std.testing.expect(getById(255) == null);
}
