const std = @import("std");
const fyr = @import("fyr");

const window = fyr.window;
const Movement = @import("behaviours/Movement.zig");
const Player = @import("prefabs/Player.zig").Player;

pub fn main() !void {
    fyr.project({
        window.title("overlife - v2.0.0");

        window.fps.setTarget(256);
        window.size.set(fyr.Vec2(1280, 720));
        window.resizing.enable();

        fyr.logInfo("asdasd", .{});
    })({
        fyr.scene("default")({
            fyr.entities(.{
                try Player(),

                try fyr.entity("Enemy1", .{
                    fyr.Transform{
                        .position = fyr.Vec3(72, 0, 0),
                    },
                    fyr.Renderer.init(.{
                        .img = "sprites/entity/enemies/brute/left_0.png",
                    }),
                    fyr.RectCollider.init(.{
                        .rect = fyr.Rect(0, 0, 64, 64),
                        .dynamic = true,
                        .weight = 1.1,
                        .onCollisionEnter = struct {
                            pub fn callback(_: *fyr.Entity, other: *fyr.Entity) !void {
                                std.log.debug("other_id: {s}/{x}", .{ other.id, other.uuid });
                            }
                        }.callback,
                    }),
                }),
            });
        });
    });
}
