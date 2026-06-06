const State = @import("state.zig").State;
const input = @import("input.zig");
const actions = @import("actions.zig");
const ids = @import("ids.zig");
const turn = @import("systems/turn.zig");
const energy_scheduler = @import("energy_scheduler.zig");

pub const Game = struct {
    state: State,

    pub fn init(allocator: anytype) !Game {
        var game = Game{ .state = try State.init(allocator) };
        try game.state.run.log.add("Explore the starter dungeon.");
        return game;
    }

    pub fn deinit(self: *Game) void {
        self.state.deinit();
    }

    pub fn handle(self: *Game, command: input.Command) !void {
        // Convert command to intent; null means no-op
        const intent = actions.intentFromCommand(command) orelse return;

        // Quit is handled at the State level before validation/execution
        if (intent == .quit) {
            self.state.quit_requested = true;
            self.state.current_mode = .game_over;
            return;
        }

        // Validate intent against current game state (e.g. wall check)
        const action = actions.validateIntent(intent, &self.state.run) orelse return;

        // Execute the validated action
        try actions.executeAction(action, &self.state.run);

        // Deduct energy from the player after acting
        self.state.run.scheduler.deductCost(ids.player_actor_id, actions.costOf(action));

        // Tick all actors, then run every non-player actor that has enough energy.
        // Must tick BEFORE checking enemies so slower actors accumulate correctly.
        self.state.run.scheduler.tick();
        var i: usize = 1; // slot 0 is always player
        while (i < self.state.run.scheduler.count) : (i += 1) {
            const slot = &self.state.run.scheduler.actors[i];
            if (slot.energy >= energy_scheduler.ACTION_THRESHOLD) {
                const cost = try turn.endActorTurn(&self.state.run, slot.id);
                self.state.run.scheduler.deductCost(slot.id, cost);
            }
        }
    }
};
