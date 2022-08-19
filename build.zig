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

    const bme_exe = b.addExecutable("bme", "src/bme.zig");
    bme_exe.setTarget(target);
    bme_exe.setBuildMode(mode);
    bme_exe.addPackage(libbm_pkg);
    bme_exe.install();

    const bme_run_cmd = bme_exe.run();
    bme_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        bme_run_cmd.addArgs(args);
    }

    const run_bme_step = b.step("run-bme", "Run bme");
    run_bme_step.dependOn(&bme_run_cmd.step);

    const debasm_exe = b.addExecutable("debasm", "src/debasm.zig");
    debasm_exe.setTarget(target);
    debasm_exe.setBuildMode(mode);
    debasm_exe.addPackage(libbm_pkg);
    debasm_exe.install();

    const debasm_run_cmd = debasm_exe.run();
    debasm_run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        debasm_run_cmd.addArgs(args);
    }

    const run_debasm_step = b.step("run-debasm", "Run debasm");
    run_debasm_step.dependOn(&debasm_run_cmd.step);

    const examples = [_][]const u8{
        "fib",
    };

    var example_cmds: [examples.len]*std.build.RunStep = undefined;

    var i: usize = 0;
    while (i < examples.len) : (i += 1) {
        const example = examples[i];
        const basm_example = basm_exe.run();
        const basm_arg = try std.mem.concat(b.allocator, u8, &.{ "examples/", example, ".basm" });
        defer b.allocator.free(basm_arg);
        const bm_arg = try std.mem.concat(b.allocator, u8, &.{ "examples/", example, ".bm" });
        defer b.allocator.free(bm_arg);
        basm_example.addArgs(&.{ basm_arg, bm_arg });
        const bme_example = bme_exe.run();
        bme_example.addArg(bm_arg);
        bme_example.step.dependOn(&basm_example.step);
        example_cmds[i] = bme_example;
    }

    const run_examples_step = b.step("run-examples", "Run all examples");
    for (example_cmds) |cmd| {
        run_examples_step.dependOn(&cmd.step);
    }
}
