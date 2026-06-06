pub const actions = @import("actions.zig");
pub const factions = @import("factions.zig");
pub const config = @import("config.zig");
pub const energy_scheduler = @import("energy_scheduler.zig");
pub const rng = @import("rng.zig");
pub const ids = @import("ids.zig");
pub const input = @import("input.zig");
pub const render = @import("render.zig");
pub const game_mode = @import("game_mode.zig");
pub const State = @import("state.zig").State;
pub const RunState = @import("run_state.zig").RunState;
pub const CampaignState = @import("campaign_state.zig").CampaignState;
pub const Game = @import("game.zig").Game;

pub const world = struct {
    pub const tile = @import("world/tile.zig");
    pub const map = @import("world/map.zig");
    pub const generation = @import("world/generation.zig");
};

pub const entities = struct {
    pub const entity = @import("entities/entity.zig");
    pub const player = @import("entities/player.zig");
    pub const enemy = @import("entities/enemy.zig");
};

pub const systems = struct {
    pub const movement = @import("systems/movement.zig");
    pub const turn = @import("systems/turn.zig");
    pub const combat = @import("systems/combat.zig");
};

pub const ui = struct {
    pub const hud = @import("ui/hud.zig");
    pub const log = @import("ui/log.zig");
};

pub const stores = struct {
    pub const actor_store = @import("stores/actor_store.zig");
    pub const item_store = @import("stores/item_store.zig");
};

pub const status = @import("status.zig");
pub const visibility = @import("visibility.zig");

pub const ai = struct {
    pub const behavior = @import("ai/behavior.zig");
    pub const pathfind = @import("ai/pathfind.zig");
    pub const ai_system = @import("ai/ai_system.zig");
};
