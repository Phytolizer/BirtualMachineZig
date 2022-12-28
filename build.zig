const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const Exe = enum(usize) {
        basm = 0,
        bme = 1,
    };
    const exes = [_][]const u8{ "basm", "bme" };
    var build_steps: [exes.len]*std.build.LibExeObjStep = undefined;
    inline for (exes) |name, i| {
        const enum_value = std.meta.fieldNames(Exe)[i];
        std.debug.assert(std.mem.eql(u8, enum_value, name));

        const exe = b.addExecutable(name, "src/" ++ name ++ ".zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();

        build_steps[i] = exe;

        const run_command = exe.run();
        run_command.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_command.addArgs(args);
        }
        run_command.expected_exit_code = null;

        const run_step = b.step("run-" ++ name, "Run " ++ name);
        run_step.dependOn(&run_command.step);
    }

    var examples_dir = try std.fs.cwd().openIterableDir("examples", .{});
    defer examples_dir.close();

    const examples_step = b.step("examples", "Run examples");
    var examples_iter = examples_dir.iterate();
    while (try examples_iter.next()) |entry| {
        if (std.mem.eql(u8, std.fs.path.extension(entry.name), ".basm")) {
            const full_path = try std.fs.path.join(
                b.allocator,
                &.{ "examples", entry.name },
            );
            const bm_path = try std.mem.concat(b.allocator, u8, &.{
                "examples/",
                std.fs.path.stem(entry.name),
                ".bm",
            });
            const step = try b.allocator.create(std.build.Step);
            step.* = std.build.Step.initNoOp(.custom, try std.fmt.allocPrint(
                b.allocator,
                "example-{s}",
                .{std.fs.path.stem(entry.name)},
            ), b.allocator);
            const basm_step = try b.allocator.create(std.build.Step);
            basm_step.* = std.build.Step.initNoOp(.custom, try std.fmt.allocPrint(
                b.allocator,
                "example-{s}-basm",
                .{std.fs.path.stem(entry.name)},
            ), b.allocator);
            const basm_run_cmd = build_steps[@enumToInt(Exe.basm)].run();
            basm_run_cmd.addArgs(&.{ full_path, bm_path });
            basm_step.dependOn(&basm_run_cmd.step);
            const bme_step = try b.allocator.create(std.build.Step);
            bme_step.* = std.build.Step.initNoOp(.custom, try std.fmt.allocPrint(
                b.allocator,
                "example-{s}-bme",
                .{std.fs.path.stem(entry.name)},
            ), b.allocator);
            const bme_run_cmd = build_steps[@enumToInt(Exe.bme)].run();
            bme_run_cmd.addArg(bm_path);
            bme_step.dependOn(&bme_run_cmd.step);

            step.dependOn(basm_step);
            step.dependOn(bme_step);
            examples_step.dependOn(step);
        }
    }
}
