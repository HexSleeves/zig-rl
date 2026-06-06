/// CampaignState holds persistent cross-run data.
/// Stub for Milestone 0; more fields added in Milestone 7.
pub const CampaignState = struct {
    runs_completed: u32,
    best_floor: u32,

    pub fn init() CampaignState {
        return .{
            .runs_completed = 0,
            .best_floor = 0,
        };
    }
};
