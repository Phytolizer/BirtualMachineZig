const std = @import("std");

const Builder = std.build.Builder;
const Pkg = std.build.Pkg;

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const libbm = b.addStaticLibrary("bm", "src/libbm.zig");
    libbm.setTarget(target);
    libbm.setBuildMode(mode);
    libbm.install();
    const libbm_pkg = Pkg{
        .name = "bm",
        .source = .{ .path = "src/libbm.zig" },
    };

    const basm_exe = b.addExecutable("basm", "src/basm.zig");
    basm_exe.setTarget(target);
    basm_exe.setBuildMode(mode);
    basm_exe.addPackage(libbm_pkg);
    basm_exe.install();

    const basm_run_cmd = basm_exe.run();
    basm_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        basm_run_cmd.addArgs(args);
    }

    const run_basm_step = b.step("run-basm", "Run basm");
    run_basm_step.dependOn(&basm_run_cmd.step);
}
