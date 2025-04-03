const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const fyr_module = b.dependency("fyr", .{
        .target = target,
        .optimize = optimize,
    });
    const fyr = fyr_module.module("fyr");

    const exe = b.addExecutable(.{
        .name = "overlife",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });

    exe.root_module.addImport("fyr", fyr);

    if (target.result.os.tag != .macos) {
        exe.linkLibC();
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "run overlife");
    run_step.dependOn(&run_cmd.step);
}
