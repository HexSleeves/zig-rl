const std = @import("std");
const ids = @import("../ids.zig");
const config = @import("../config.zig");
const map_object = @import("../world/map_object.zig");

pub const ObjectStore = struct {
    objects: [config.max_objects]map_object.MapObject,
    count: usize,
    next_id: u32,

    pub fn init() ObjectStore {
        return ObjectStore{
            .objects = undefined,
            .count = 0,
            .next_id = 1,
        };
    }

    pub fn addObject(
        self: *ObjectStore,
        x: i32,
        y: i32,
        kind: map_object.ObjectKind,
        state: map_object.ObjectState,
        difficulty: u8,
    ) ?ids.ObjectId {
        if (self.count >= config.max_objects) return null;
        const new_id = ids.ObjectId{ .value = self.next_id };
        self.next_id += 1;
        self.objects[self.count] = .{
            .id = new_id,
            .x = x,
            .y = y,
            .kind = kind,
            .state = state,
            .powered = true,
            .difficulty = difficulty,
            .alive = true,
            .facing = 0,
        };
        self.count += 1;
        return new_id;
    }

    pub fn getObject(self: *const ObjectStore, id: ids.ObjectId) ?*const map_object.MapObject {
        for (self.objects[0..self.count]) |*obj| {
            if (obj.alive and obj.id.eql(id)) return obj;
        }
        return null;
    }

    pub fn getObjectMut(self: *ObjectStore, id: ids.ObjectId) ?*map_object.MapObject {
        for (self.objects[0..self.count]) |*obj| {
            if (obj.alive and obj.id.eql(id)) return obj;
        }
        return null;
    }

    pub fn objectAt(self: *const ObjectStore, x: i32, y: i32) ?ids.ObjectId {
        for (self.objects[0..self.count]) |*obj| {
            if (obj.alive and obj.x == x and obj.y == y) return obj.id;
        }
        return null;
    }

    pub fn removeObject(self: *ObjectStore, id: ids.ObjectId) void {
        for (self.objects[0..self.count]) |*obj| {
            if (obj.id.eql(id)) {
                obj.alive = false;
                return;
            }
        }
    }
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

test "ObjectStore init is empty" {
    const store = ObjectStore.init();
    try std.testing.expectEqual(@as(usize, 0), store.count);
}

test "ObjectStore addObject returns id" {
    var store = ObjectStore.init();
    const id = store.addObject(5, 5, .door, .closed, 3);
    try std.testing.expect(id != null);
    try std.testing.expectEqual(@as(usize, 1), store.count);
}

test "ObjectStore getObject returns added object" {
    var store = ObjectStore.init();
    const id = store.addObject(3, 4, .terminal, .closed, 5).?;
    const obj = store.getObject(id);
    try std.testing.expect(obj != null);
    try std.testing.expectEqual(@as(i32, 3), obj.?.x);
    try std.testing.expectEqual(@as(i32, 4), obj.?.y);
    try std.testing.expectEqual(map_object.ObjectKind.terminal, obj.?.kind);
}

test "ObjectStore objectAt finds alive object" {
    var store = ObjectStore.init();
    const id = store.addObject(10, 7, .camera, .closed, 4).?;
    const found = store.objectAt(10, 7);
    try std.testing.expect(found != null);
    try std.testing.expect(found.?.eql(id));
    try std.testing.expect(store.objectAt(0, 0) == null);
}
