pub const actions = @import("actions.zig");
pub const factions = @import("factions.zig");
pub const config = @import("config.zig");
pub const energy_scheduler = @import("energy_scheduler.zig");
pub const rng = @import("rng.zig");
pub const ids = @import("ids.zig");
pub const input = @import("input.zig");
pub const game_mode = @import("game_mode.zig");
pub const State = @import("state.zig").State;
pub const RunState = @import("run_state.zig").RunState;
pub const CampaignState = @import("campaign_state.zig").CampaignState;
pub const RunOutcome = @import("campaign_state.zig").RunOutcome;
pub const RunRecord = @import("campaign_state.zig").RunRecord;
pub const OperativeBackground = @import("campaign_state.zig").OperativeBackground;
pub const FacilityWing = @import("campaign_state.zig").FacilityWing;
pub const WingStatus = @import("campaign_state.zig").WingStatus;
pub const Game = @import("game.zig").Game;

pub const world = struct {
    pub const tile = @import("world/tile.zig");
    pub const map = @import("world/map.zig");
    pub const generation = @import("world/generation.zig");
    pub const procgen = @import("world/procgen.zig");
    pub const map_object = @import("world/map_object.zig");
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
    pub const camera = @import("ui/camera.zig");
    pub const draw = @import("ui/draw.zig");
    pub const layout = @import("ui/layout.zig");
    pub const log = @import("ui/log.zig");
    pub const scene = @import("ui/scene.zig");
    pub const theme = @import("ui/theme.zig");

    pub const panels = struct {
        pub const header = @import("ui/panels/header.zig");
        pub const inspect = @import("ui/panels/inspect.zig");
        pub const loadout = @import("ui/panels/loadout.zig");
        pub const log_panel = @import("ui/panels/log_panel.zig");
        pub const map_view = @import("ui/panels/map_view.zig");
        pub const vitals = @import("ui/panels/vitals.zig");
    };

    pub const screens = struct {
        pub const game_over = @import("ui/screens/game_over.zig");
        pub const inventory = @import("ui/screens/inventory.zig");
        pub const main_menu = @import("ui/screens/main_menu.zig");
    };
};

pub const stores = struct {
    pub const actor_store = @import("stores/actor_store.zig");
    pub const item_store = @import("stores/item_store.zig");
    pub const object_store = @import("stores/object_store.zig");
};

pub const items = struct {
    pub const item_def = @import("items/item_def.zig");
    pub const item_loader = @import("items/item_loader.zig");
    pub const inventory = @import("items/inventory.zig");
    pub const loot_table = @import("items/loot_table.zig");
};

pub const save = @import("save/save.zig");
pub const status = @import("status.zig");
pub const visibility = @import("visibility.zig");

pub const ai = struct {
    pub const behavior = @import("ai/behavior.zig");
    pub const pathfind = @import("ai/pathfind.zig");
    pub const ai_system = @import("ai/ai_system.zig");
};
