const std = @import("std");
const pkgs = @import("deps.zig").pkgs;

const Builder = std.build.Builder;
const Pkg = std.build.Pkg;

fn stripExt(path: []const u8) []const u8 {
    return if (std.mem.lastIndexOfScalar(u8, path, '.')) |i|
        path[0..i]
    else
        path;
}

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
    basm_exe.addPackage(pkgs.args);
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
    bme_exe.addPackage(pkgs.args);
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

    // Examples
    {
        var example_cmds = std.ArrayList(*std.build.RunStep).init(b.allocator);
        defer example_cmds.deinit();

        var examples_dir = try std.fs.cwd().openIterableDir("examples", .{});
        defer examples_dir.close();
        var examples_dir_iter = examples_dir.iterate();
        while (try examples_dir_iter.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".basm")) {
                continue;
            }

            const example = stripExt(entry.name);
            const basm_example = basm_exe.run();
            const basm_arg = try std.mem.concat(b.allocator, u8, &.{ "examples/", example, ".basm" });
            defer b.allocator.free(basm_arg);
            const bm_arg = try std.mem.concat(b.allocator, u8, &.{ "examples/", example, ".bm" });
            defer b.allocator.free(bm_arg);
            basm_example.addArgs(&.{ basm_arg, bm_arg });
            try example_cmds.append(basm_example);
        }

        const run_examples_step = b.step("examples", "Compile all examples");
        for (example_cmds.items) |cmd| {
            run_examples_step.dependOn(&cmd.step);
        }
    }
}
