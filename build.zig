const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exes = &[_][]const u8{"basm"};
    inline for (exes) |name| {
        const exe = b.addExecutable(name, "src/" ++ name ++ ".zig");
        exe.setTarget(target);
        exe.setBuildMode(mode);
        exe.install();

        const run_command = exe.run();
        run_command.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_command.addArgs(args);
        }
        run_command.expected_exit_code = null;

        const run_step = b.step("run-" ++ name, "Run " ++ name);
        run_step.dependOn(&run_command.step);
    }
}
