const std = @import("std");
const fyr = @import("fyr");

pub const FYR_BEHAVIOUR = {};
const Self = @This();

transform: ?*fyr.Transform = null,
speed: f32 = 370,

pub fn Start(self: *Self, entity: *fyr.Entity) !void {
    const transform = entity.getComponent(fyr.Transform) orelse Blk: {
        try entity.addComonent(fyr.Transform{});
        break :Blk entity.getComponent(fyr.Transform).?;
    };

    self.transform = transform;
}

pub fn Update(self: *Self, _: *fyr.Entity) !void {
    const transform = self.transform orelse return;

    var move_vec = fyr.vec3();

    if (fyr.input.getKey(.w)) {
        move_vec.y -= 1;
    }
    if (fyr.input.getKey(.s)) {
        move_vec.y += 1;
    }
    if (fyr.input.getKey(.a)) {
        move_vec.x -= 1;
    }
    if (fyr.input.getKey(.d)) {
        move_vec.x += 1;
    }

    move_vec = move_vec.normalize();

    transform.position = transform.position.add(move_vec.multiply(
        fyr.Vec3(
            self.speed * fyr.time.deltaTime(),
            self.speed * fyr.time.deltaTime(),
            self.speed * fyr.time.deltaTime(),
        ),
    ));
}
