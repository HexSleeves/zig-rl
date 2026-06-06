const entity = @import("entity.zig");
const ai_behavior = @import("../ai/behavior.zig");
const ids = @import("../ids.zig");
const factions = @import("../factions.zig");
const status_mod = @import("../status.zig");

pub const Enemy = struct {
    position: entity.Position,
    glyph: u8 = 'g',
    name: []const u8 = "goblin",
    alive: bool = true,

    // Combat stats
    hp: i32 = 10,
    max_hp: i32 = 10,
    armor: u32 = 0, // damage reduction per hit
    accuracy: u32 = 70, // % chance to hit (0-100)
    evasion: u32 = 10, // % chance to dodge (0-100)
    speed: u32 = 100, // energy per tick (matches BASE_SPEED)

    // Faction and perception
    faction: ids.FactionId = factions.SECURITY,
    awareness: u32 = 5, // tile radius for patrol awareness

    // AI state
    ai: ai_behavior.AiState = .{},

    // Status effects
    status: status_mod.StatusSet = status_mod.StatusSet.init(),

    pub fn isAlive(self: *const Enemy) bool {
        return self.alive and self.hp > 0;
    }

    pub fn takeDamage(self: *Enemy, amount: i32) void {
        self.hp -= amount;
        if (self.hp <= 0) {
            self.hp = 0;
            self.alive = false;
        }
    }
};
