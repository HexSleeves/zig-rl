const ids = @import("../ids.zig");

pub const ObjectKind = enum(u8) {
    door,
    terminal,
    camera,
    locker,
    alarm,
    generator,
};

pub const ObjectState = enum(u8) {
    closed,
    open,
    locked,
    hacked,
    broken,
    disabled,
};

pub const MapObject = struct {
    id: ids.ObjectId,
    x: i32,
    y: i32,
    kind: ObjectKind,
    state: ObjectState,
    powered: bool,
    difficulty: u8,
    alive: bool,
    /// Camera facing: 0=N,1=NE,2=E,3=SE,4=S,5=SW,6=W,7=NW
    facing: u8,
};
