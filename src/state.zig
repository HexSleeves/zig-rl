const std = @import("std");
const game_mode_mod = @import("game_mode.zig");
const run_state_mod = @import("run_state.zig");
const campaign_state_mod = @import("campaign_state.zig");
const RunOutcome = campaign_state_mod.RunOutcome;
const RunRecord = campaign_state_mod.RunRecord;

pub const GameMode = game_mode_mod.GameMode;
pub const RunState = run_state_mod.RunState;
pub const CampaignState = campaign_state_mod.CampaignState;

pub const State = struct {
    allocator: std.mem.Allocator,
    run: RunState,
    campaign: CampaignState,
    current_mode: GameMode,
    quit_requested: bool,

    pub fn init(allocator: std.mem.Allocator) !State {
        return State{
            .allocator = allocator,
            .run = try RunState.init(allocator),
            .campaign = CampaignState.init(),
            .current_mode = .running,
            .quit_requested = false,
        };
    }

    pub fn deinit(self: *State) void {
        self.run.deinit();
    }

    /// Record the end of the current run into campaign state.
    /// Computes score from run metrics, stores a RunRecord, then triggers unlock progression.
    pub fn endRun(self: *State, outcome: RunOutcome) void {
        const score: u32 = self.run.kills * 10 +
            self.run.current_floor * 50 +
            self.run.items_found * 5;
        const record = RunRecord{
            .outcome = outcome,
            .floor = self.run.current_floor,
            .score = score,
            .turn_count = self.run.turn_count,
            .kills = self.run.kills,
            .items_found = self.run.items_found,
        };
        self.campaign.recordRunEnd(record);
        self.current_mode = .campaign_summary;
    }

    /// Backward-compat accessor: get enemy glyph at position.
    pub fn enemyGlyphAt(self: *const State, x: i32, y: i32) ?u8 {
        return self.run.enemyGlyphAt(x, y);
    }
};
