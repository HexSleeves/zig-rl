const std = @import("std");

// ---------------------------------------------------------------------------
// Run outcome
// ---------------------------------------------------------------------------

pub const RunOutcome = enum(u8) {
    extraction_success,
    facility_shutdown,
    ai_assimilation,
    reactor_meltdown,
    blacksite_exposure,
    operative_death,
    quit,
};

// ---------------------------------------------------------------------------
// Operative backgrounds
// ---------------------------------------------------------------------------

pub const OperativeBackground = enum(u8) {
    default_operative = 0,
    ex_military = 1,
    hacker = 2,
    infiltrator = 3,
    medic = 4,
    engineer = 5,
};

pub const BACKGROUND_COUNT: usize = 6;

// ---------------------------------------------------------------------------
// Campaign map — facility wings
// ---------------------------------------------------------------------------

pub const FacilityWing = enum(u8) {
    alpha_sector = 0, // Starting wing — always available
    beta_sector = 1, // Unlocked after first extraction success
    gamma_sector = 2, // Unlocked after beta completed
    delta_sector = 3, // Final wing, locked until gamma completed
};

pub const WING_COUNT: usize = 4;

pub const WingStatus = enum(u8) {
    locked,
    available,
    completed,
    failed,
};

// ---------------------------------------------------------------------------
// Per-run record
// ---------------------------------------------------------------------------

pub const RunRecord = struct {
    outcome: RunOutcome,
    floor: u32,
    score: u32,
    turn_count: u64,
    kills: u32,
    items_found: u32,
};

// ---------------------------------------------------------------------------
// CampaignState
// ---------------------------------------------------------------------------

pub const MAX_ITEM_IDS: usize = 32; // covers current 18 item defs + headroom
pub const MAX_RUN_HISTORY: usize = 20;

pub const CampaignState = struct {
    // Unlock pools — expanded run content, no raw stat upgrades
    unlocked_items: std.bit_set.StaticBitSet(MAX_ITEM_IDS),
    unlocked_backgrounds: std.bit_set.StaticBitSet(BACKGROUND_COUNT),

    // Glossary — items and enemies seen across all runs
    seen_item_defs: std.bit_set.StaticBitSet(MAX_ITEM_IDS),
    seen_enemy_glyphs: std.bit_set.StaticBitSet(128), // indexed by ASCII glyph

    // Lore / intel discovered
    discovered_lore: std.bit_set.StaticBitSet(32),

    // Run statistics
    runs_completed: u32,
    runs_failed: u32,
    best_floor: u32,
    best_score: u32,
    total_kills: u32,
    completed_objectives: u32,

    // Run history — circular buffer of recent runs
    run_history: [MAX_RUN_HISTORY]RunRecord,
    history_count: usize,
    history_next: usize,

    // Campaign map wing progression
    wing_status: [WING_COUNT]WingStatus,

    pub fn init() CampaignState {
        var s = CampaignState{
            .unlocked_items = std.bit_set.StaticBitSet(MAX_ITEM_IDS).initEmpty(),
            .unlocked_backgrounds = std.bit_set.StaticBitSet(BACKGROUND_COUNT).initEmpty(),
            .seen_item_defs = std.bit_set.StaticBitSet(MAX_ITEM_IDS).initEmpty(),
            .seen_enemy_glyphs = std.bit_set.StaticBitSet(128).initEmpty(),
            .discovered_lore = std.bit_set.StaticBitSet(32).initEmpty(),
            .runs_completed = 0,
            .runs_failed = 0,
            .best_floor = 0,
            .best_score = 0,
            .total_kills = 0,
            .completed_objectives = 0,
            .run_history = undefined,
            .history_count = 0,
            .history_next = 0,
            .wing_status = [_]WingStatus{.locked} ** WING_COUNT,
        };
        // Alpha sector always available from the start
        s.wing_status[@intFromEnum(FacilityWing.alpha_sector)] = .available;
        // Default operative background is always unlocked
        s.unlocked_backgrounds.set(@intFromEnum(OperativeBackground.default_operative));
        return s;
    }

    // ---------------------------------------------------------------------------
    // Run tracking
    // ---------------------------------------------------------------------------

    pub fn recordRunEnd(self: *CampaignState, record: RunRecord) void {
        switch (record.outcome) {
            .extraction_success,
            .facility_shutdown,
            .ai_assimilation,
            .reactor_meltdown,
            .blacksite_exposure,
            => {
                self.runs_completed += 1;
                if (record.score > self.best_score) self.best_score = record.score;
            },
            .operative_death, .quit => {
                self.runs_failed += 1;
            },
        }

        if (record.floor > self.best_floor) self.best_floor = record.floor;
        self.total_kills += record.kills;

        self.run_history[self.history_next] = record;
        self.history_next = (self.history_next + 1) % MAX_RUN_HISTORY;
        if (self.history_count < MAX_RUN_HISTORY) self.history_count += 1;

        self.applyUnlockProgression(record);
    }

    pub fn getLastRun(self: *const CampaignState) ?RunRecord {
        if (self.history_count == 0) return null;
        const idx = if (self.history_next == 0) MAX_RUN_HISTORY - 1 else self.history_next - 1;
        return self.run_history[idx];
    }

    // ---------------------------------------------------------------------------
    // Unlock pool
    // ---------------------------------------------------------------------------

    pub fn unlockItem(self: *CampaignState, def_id: u16) void {
        if (def_id < MAX_ITEM_IDS) self.unlocked_items.set(def_id);
    }

    pub fn isItemUnlocked(self: *const CampaignState, def_id: u16) bool {
        if (def_id >= MAX_ITEM_IDS) return false;
        return self.unlocked_items.isSet(def_id);
    }

    pub fn unlockBackground(self: *CampaignState, bg: OperativeBackground) void {
        self.unlocked_backgrounds.set(@intFromEnum(bg));
    }

    pub fn isBackgroundUnlocked(self: *const CampaignState, bg: OperativeBackground) bool {
        return self.unlocked_backgrounds.isSet(@intFromEnum(bg));
    }

    // ---------------------------------------------------------------------------
    // Glossary
    // ---------------------------------------------------------------------------

    pub fn seeItemDef(self: *CampaignState, def_id: u16) void {
        if (def_id < MAX_ITEM_IDS) self.seen_item_defs.set(def_id);
    }

    pub fn hasSeenItemDef(self: *const CampaignState, def_id: u16) bool {
        if (def_id >= MAX_ITEM_IDS) return false;
        return self.seen_item_defs.isSet(def_id);
    }

    pub fn seeEnemyGlyph(self: *CampaignState, glyph: u8) void {
        self.seen_enemy_glyphs.set(glyph);
    }

    pub fn hasSeenEnemyGlyph(self: *const CampaignState, glyph: u8) bool {
        return self.seen_enemy_glyphs.isSet(glyph);
    }

    // ---------------------------------------------------------------------------
    // Lore / intel
    // ---------------------------------------------------------------------------

    pub fn discoverLore(self: *CampaignState, lore_id: u8) void {
        if (lore_id < 32) self.discovered_lore.set(lore_id);
    }

    pub fn hasDiscoveredLore(self: *const CampaignState, lore_id: u8) bool {
        if (lore_id >= 32) return false;
        return self.discovered_lore.isSet(lore_id);
    }

    // ---------------------------------------------------------------------------
    // Campaign map
    // ---------------------------------------------------------------------------

    pub fn setWingStatus(self: *CampaignState, wing: FacilityWing, status: WingStatus) void {
        self.wing_status[@intFromEnum(wing)] = status;
    }

    pub fn getWingStatus(self: *const CampaignState, wing: FacilityWing) WingStatus {
        return self.wing_status[@intFromEnum(wing)];
    }

    // ---------------------------------------------------------------------------
    // Internal — unlock progression after run end
    // ---------------------------------------------------------------------------

    fn applyUnlockProgression(self: *CampaignState, record: RunRecord) void {
        // Unlock beta sector after first extraction success
        if (record.outcome == .extraction_success) {
            if (self.wing_status[@intFromEnum(FacilityWing.beta_sector)] == .locked) {
                self.wing_status[@intFromEnum(FacilityWing.beta_sector)] = .available;
            }
        }

        // Unlock ex_military background after any run with >=5 kills
        if (record.kills >= 5 and !self.isBackgroundUnlocked(.ex_military)) {
            self.unlockBackground(.ex_military);
        }

        // Unlock hacker background after facility_shutdown outcome
        if (record.outcome == .facility_shutdown and !self.isBackgroundUnlocked(.hacker)) {
            self.unlockBackground(.hacker);
        }

        // Gamma unlocks when beta is completed
        if (self.wing_status[@intFromEnum(FacilityWing.beta_sector)] == .completed and
            self.wing_status[@intFromEnum(FacilityWing.gamma_sector)] == .locked)
        {
            self.wing_status[@intFromEnum(FacilityWing.gamma_sector)] = .available;
        }

        // Delta unlocks when gamma is completed
        if (self.wing_status[@intFromEnum(FacilityWing.gamma_sector)] == .completed and
            self.wing_status[@intFromEnum(FacilityWing.delta_sector)] == .locked)
        {
            self.wing_status[@intFromEnum(FacilityWing.delta_sector)] = .available;
        }
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "CampaignState init: alpha available, default operative unlocked" {
    const campaign = CampaignState.init();
    try std.testing.expectEqual(WingStatus.available, campaign.getWingStatus(.alpha_sector));
    try std.testing.expectEqual(WingStatus.locked, campaign.getWingStatus(.beta_sector));
    try std.testing.expect(campaign.isBackgroundUnlocked(.default_operative));
    try std.testing.expect(!campaign.isBackgroundUnlocked(.ex_military));
}

test "CampaignState: successful run increments runs_completed and updates best floor" {
    var campaign = CampaignState.init();
    campaign.recordRunEnd(.{
        .outcome = .extraction_success,
        .floor = 3,
        .score = 150,
        .turn_count = 400,
        .kills = 6,
        .items_found = 3,
    });
    try std.testing.expectEqual(@as(u32, 1), campaign.runs_completed);
    try std.testing.expectEqual(@as(u32, 0), campaign.runs_failed);
    try std.testing.expectEqual(@as(u32, 3), campaign.best_floor);
    try std.testing.expectEqual(@as(u32, 150), campaign.best_score);
}

test "CampaignState: failed run increments runs_failed" {
    var campaign = CampaignState.init();
    campaign.recordRunEnd(.{
        .outcome = .operative_death,
        .floor = 1,
        .score = 20,
        .turn_count = 100,
        .kills = 2,
        .items_found = 1,
    });
    try std.testing.expectEqual(@as(u32, 0), campaign.runs_completed);
    try std.testing.expectEqual(@as(u32, 1), campaign.runs_failed);
}

test "CampaignState: extraction unlocks beta sector" {
    var campaign = CampaignState.init();
    campaign.recordRunEnd(.{
        .outcome = .extraction_success,
        .floor = 2,
        .score = 100,
        .turn_count = 300,
        .kills = 3,
        .items_found = 2,
    });
    try std.testing.expectEqual(WingStatus.available, campaign.getWingStatus(.beta_sector));
}

test "CampaignState: 5+ kills unlocks ex_military background" {
    var campaign = CampaignState.init();
    campaign.recordRunEnd(.{
        .outcome = .operative_death,
        .floor = 1,
        .score = 50,
        .turn_count = 200,
        .kills = 5,
        .items_found = 0,
    });
    try std.testing.expect(campaign.isBackgroundUnlocked(.ex_military));
}

test "CampaignState: facility_shutdown unlocks hacker background" {
    var campaign = CampaignState.init();
    campaign.recordRunEnd(.{
        .outcome = .facility_shutdown,
        .floor = 4,
        .score = 400,
        .turn_count = 800,
        .kills = 1,
        .items_found = 5,
    });
    try std.testing.expect(campaign.isBackgroundUnlocked(.hacker));
}

test "CampaignState: run history circular buffer" {
    var campaign = CampaignState.init();
    const record = RunRecord{
        .outcome = .quit,
        .floor = 1,
        .score = 0,
        .turn_count = 10,
        .kills = 0,
        .items_found = 0,
    };
    campaign.recordRunEnd(record);
    const last = campaign.getLastRun().?;
    try std.testing.expectEqual(RunOutcome.quit, last.outcome);
    try std.testing.expectEqual(@as(usize, 1), campaign.history_count);
}

test "CampaignState: glossary tracking" {
    var campaign = CampaignState.init();
    try std.testing.expect(!campaign.hasSeenItemDef(6));
    campaign.seeItemDef(6);
    try std.testing.expect(campaign.hasSeenItemDef(6));

    try std.testing.expect(!campaign.hasSeenEnemyGlyph('g'));
    campaign.seeEnemyGlyph('g');
    try std.testing.expect(campaign.hasSeenEnemyGlyph('g'));
}

test "CampaignState: lore tracking" {
    var campaign = CampaignState.init();
    try std.testing.expect(!campaign.hasDiscoveredLore(0));
    campaign.discoverLore(0);
    try std.testing.expect(campaign.hasDiscoveredLore(0));
}

test "CampaignState: unlock item pool" {
    var campaign = CampaignState.init();
    try std.testing.expect(!campaign.isItemUnlocked(2));
    campaign.unlockItem(2);
    try std.testing.expect(campaign.isItemUnlocked(2));
}
