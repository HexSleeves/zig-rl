const State = @import("state.zig").State;
const input = @import("input.zig");
const actions = @import("actions.zig");
const ids = @import("ids.zig");

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
    }
};
