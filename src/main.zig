const std = @import("std");

const os = @import("std").os;
const fs = @import("std").fs;

const e = @import("./engine/engine.m.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    e.setTraceLogLevel(.log_error);

    e.window.init(
        "HadeSpear",
        e.Vec2(
            1440,
            720,
        ),
    );
    defer e.window.deinit();

    try e.compile();
    try e.init(&allocator);
    defer e.deinit() catch {};

    e.setTargetFPS(256);

    while (!e.windowShouldClose()) {
        e.update() catch {};
    }
}
