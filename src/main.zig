const std = @import("std");
const fyr = @import("fyr");

const window = fyr.window;

const Movement = @import("behaviours/Movement.zig");

pub fn main() !void {
    fyr.project({
        window.title("overlife - v2.0.0");

        window.resizing.enable();
        window.size.set(fyr.Vec2(1280, 720));
        window.fps.setTarget(256);
    })({
        fyr.scene("default")({
            fyr.entities(.{
                try fyr.entity("Player", .{
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
                }),

                try fyr.entity("Enemy1", .{
                    fyr.Transform{},
                    fyr.Renderer.init(.{
                        .img = "sprites/entity/angler/left.png",
                    }),
                }),
            });
        });
    });
}
