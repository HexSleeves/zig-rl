const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    const zopengl = b.dependency("zopengl", .{});
    const zgui = b.dependency("zgui", .{
        .target = target,
        .optimize = optimize,
        .backend = .glfw_opengl3,
    });

    exe_mod.addImport("zglfw", zglfw.module("root"));
    exe_mod.addImport("zopengl", zopengl.module("root"));
    exe_mod.addImport("zgui", zgui.module("root"));
    exe_mod.linkLibrary(zglfw.artifact("glfw"));
    exe_mod.linkLibrary(zgui.artifact("imgui"));

    const exe = b.addExecutable(.{
        .name = "zig-rl",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the playable roguelike prototype");
    run_step.dependOn(&run_cmd.step);

    const zgd_style_run_step = b.step("roguelike-run", "zig-gamedev-style alias for running the sample");
    zgd_style_run_step.dependOn(&run_cmd.step);

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const test_mod = b.createModule(.{
        .root_source_file = b.path("tests/simulation.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("zig_rl", lib_mod);
    const unit_tests = b.addTest(.{
        .name = "zig-rl-tests",
        .root_module = test_mod,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run deterministic simulation tests");
    test_step.dependOn(&run_unit_tests.step);

    const zgd_style_test_step = b.step("roguelike-test", "zig-gamedev-style alias for running simulation tests");
    zgd_style_test_step.dependOn(&run_unit_tests.step);
}
