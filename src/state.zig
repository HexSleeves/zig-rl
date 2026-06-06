const std = @import("std");
const game_mode_mod = @import("game_mode.zig");
const run_state_mod = @import("run_state.zig");
const campaign_state_mod = @import("campaign_state.zig");

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

    /// Backward-compat accessor: get enemy glyph at position.
    pub fn enemyGlyphAt(self: *const State, x: i32, y: i32) ?u8 {
        return self.run.enemyGlyphAt(x, y);
    }
};
