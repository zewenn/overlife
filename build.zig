const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "OverLife",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    //web exports are completely separate
    // if (target.query.os_tag == .emscripten) {
    //     const exe_lib = rlz.emcc.compileForEmscripten(b, "OverLife", "src/main.zig", target, optimize);

    //     exe_lib.linkLibrary(raylib_artifact);
    //     exe_lib.root_module.addImport("raylib", raylib);

    //     // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
    //     const link_step = try rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact });

    //     b.getInstallStep().dependOn(&link_step.step);
    //     const run_step = try rlz.emcc.emscriptenRunStep(b);
    //     run_step.step.dependOn(&link_step.step);
    //     const run_option = b.step("run", "Run OverLife");
    //     run_option.dependOn(&run_step.step);
    //     return;
    // }

    const fyr_module = b.dependency("fyr", .{
        .target = target,
        .optimize = optimize,
    });

    const fyr = fyr_module.module("fyr");
    exe.root_module.addImport("fyr", fyr);

    if (target.result.os.tag != .macos) {
        exe.linkLibC();
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("run", "run overlife");
    run_step.dependOn(&run_cmd.step);
}
