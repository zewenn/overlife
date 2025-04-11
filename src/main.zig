const std = @import("std");
const fyr = @import("fyr");

const window = fyr.window;
const Movement = @import("behaviours/Movement.zig");
const Player = @import("prefabs/Player.zig").Player;

pub fn main() !void {
    fyr.project({
        window.title("overlife - v2.0.0");

        window.resizing.enable();
        window.size.set(fyr.Vec2(1280, 720));
        window.fps.setTarget(256);
    })({
        fyr.scene("default")({
            fyr.entities(.{
                try Player(),

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
