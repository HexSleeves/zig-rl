pub const Position = struct {
    x: i32,
    y: i32,

    pub fn translated(self: Position, delta: Position) Position {
        return .{
            .x = self.x + delta.x,
            .y = self.y + delta.y,
        };
    }
};
