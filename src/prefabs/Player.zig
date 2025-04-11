const std = @import("std");
const fyr = @import("fyr");

const Movement = @import("../behaviours/Movement.zig");

pub fn Player() !*fyr.Entity {
    return try fyr.entity("Player", .{
        fyr.Transform{},
        fyr.Renderer.init(.{
            .img = "sprites/entity/player/left_0.png",
        }),
        fyr.CameraTarget{
            .max_distance = 400,
            .min_distance = 50,
            .follow_speed = 360,
        },

        Movement{},
    });
}
