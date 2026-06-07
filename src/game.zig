const std = @import("std");
const Io = std.Io;
const State = @import("state.zig").State;
const input = @import("input.zig");
const actions = @import("actions.zig");
const ids = @import("ids.zig");
const turn = @import("systems/turn.zig");
const energy_scheduler = @import("energy_scheduler.zig");
const campaign_state = @import("campaign_state.zig");
const save = @import("save/save.zig");

pub const Game = struct {
    state: State,
    io: Io,

    pub fn init(allocator: anytype, io: Io) !Game {
        const campaign = save.loadCampaign(io) catch campaign_state.CampaignState.init();
        var game = Game{
            .state = try State.init(allocator),
            .io = io,
        };
        game.state.campaign = campaign;
        try game.state.run.log.add("Explore the starter dungeon.");
        return game;
    }

    pub fn deinit(self: *Game) void {
        self.state.deinit();
    }

    pub fn handle(self: *Game, command: input.Command) !void {
        const intent = actions.intentFromCommand(command) orelse return;

        if (intent == .quit) {
            self.state.quit_requested = true;
            save.saveCampaign(self.io, &self.state.campaign) catch {};
            self.state.endRun(.quit);
            return;
        }

        const action = actions.validateIntent(intent, &self.state.run) orelse return;
        try actions.executeAction(action, &self.state.run);
        self.state.run.scheduler.deductCost(ids.player_actor_id, actions.costOf(action));

        self.state.run.scheduler.tick();
        var i: usize = 1;
        while (i < self.state.run.scheduler.count) : (i += 1) {
            const slot = &self.state.run.scheduler.actors[i];
            if (slot.energy >= energy_scheduler.ACTION_THRESHOLD) {
                const cost = try turn.endActorTurn(&self.state.run, slot.id);
                self.state.run.scheduler.deductCost(slot.id, cost);
            }
        }

        if (self.state.run.player.hp <= 0) {
            save.saveCampaign(self.io, &self.state.campaign) catch {};
            self.state.endRun(.operative_death);
            self.state.current_mode = .game_over;
            return;
        }

        self.state.run.tickCameras();
        self.state.run.tickAlertDecay();

        if (self.state.run.alert_level >= 80) {
            var j: usize = 0;
            while (j < self.state.run.objects.count) : (j += 1) {
                const obj = &self.state.run.objects.objects[j];
                if (!obj.alive) continue;
                if (obj.kind == .door and obj.state == .closed) {
                    obj.state = .locked;
                }
            }
        }

        // Autosave run state every turn
        save.saveRun(self.io, &self.state.run) catch {};
    }
};
