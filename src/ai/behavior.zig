pub const AiMode = enum {
    idle,
    patrol,
    chase,
    flee,
    sentry,
};

pub const AiState = struct {
    mode: AiMode = .patrol,
    last_seen_player_x: i32 = 0,
    last_seen_player_y: i32 = 0,
    turns_since_saw_player: u32 = 0,
};
