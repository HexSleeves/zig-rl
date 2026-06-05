pub const config = @import("config.zig");
pub const rng = @import("rng.zig");
pub const ids = @import("ids.zig");
pub const input = @import("input.zig");
pub const render = @import("render.zig");
pub const State = @import("state.zig").State;

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
