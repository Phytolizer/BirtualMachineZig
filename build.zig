const std = @import("std");

const Builder = std.build.Builder;
const Pkg = std.build.Pkg;

pub fn build(b: *Builder) !void {
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

    const bmi_exe = b.addExecutable("bmi", "src/bmi.zig");
    bmi_exe.setTarget(target);
    bmi_exe.setBuildMode(mode);
    bmi_exe.addPackage(libbm_pkg);
    bmi_exe.install();

    const bmi_run_cmd = bmi_exe.run();
    bmi_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        bmi_run_cmd.addArgs(args);
    }

    const run_bmi_step = b.step("run-bmi", "Run bmi");
    run_bmi_step.dependOn(&bmi_run_cmd.step);

    const examples = [_][]const u8{
        "fib",
    };

    var gpAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpAllocator.backing_allocator;

    var example_cmds = std.ArrayList(*std.build.RunStep).init(allocator);
    defer example_cmds.deinit();

    for (examples) |example| {
        const basm_example = basm_exe.run();
        const basm_arg = try std.mem.concat(allocator, u8, &.{ "examples/", example, ".basm" });
        defer allocator.free(basm_arg);
        const bm_arg = try std.mem.concat(allocator, u8, &.{ "examples/", example, ".bm" });
        defer allocator.free(bm_arg);
        basm_example.addArgs(&.{ basm_arg, bm_arg });
        const bmi_example = bmi_exe.run();
        bmi_example.addArg(bm_arg);
        bmi_example.step.dependOn(&basm_example.step);
        try example_cmds.append(bmi_example);
    }

    const run_examples_step = b.step("run-examples", "Run all examples");
    for (example_cmds.items) |cmd| {
        run_examples_step.dependOn(&cmd.step);
    }
}
