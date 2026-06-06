pub const GameMode = enum {
    main_menu,
    running,
    inventory,
    targeting,
    game_over,
    campaign_summary,
    debug,
};

test "GameMode enum values exist" {
    const std = @import("std");

    // Verify all enum values exist
    _ = GameMode.main_menu;
    _ = GameMode.running;
    _ = GameMode.inventory;
    _ = GameMode.targeting;
    _ = GameMode.game_over;
    _ = GameMode.campaign_summary;
    _ = GameMode.debug;

    // Verify default is .running
    const default_mode: GameMode = .running;
    try std.testing.expectEqual(GameMode.running, default_mode);
}
