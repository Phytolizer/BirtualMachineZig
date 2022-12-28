const std = @import("std");
const bm = @import("bm.zig");
const arg = @import("arg.zig");

var machine = bm.Bm{};

pub fn main() void {
    run() catch std.process.exit(1);
}

fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const a = gpa.allocator();

    const args_buf = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args_buf);

    var args = args_buf;
    const program = arg.shift(&args) orelse unreachable;
    const usage = arg.genUsage("-i <input.bm> [-l <limit>]");

    var opt_in_path: ?[]const u8 = null;
    var limit: ?usize = null;
    const stdout = std.io.getStdOut().writer();

    while (arg.shift(&args)) |flag| {
        if (std.mem.eql(u8, flag, "-i")) {
            opt_in_path = arg.shift(&args) orelse return arg.showErr(
                usage,
                program,
                "no argument provided for `{s}`",
                .{flag},
            );
        } else if (std.mem.eql(u8, flag, "-l")) {
            const limit_str = arg.shift(&args) orelse
                return arg.showErr(usage, program, "no argument provided for `{s}`\n", .{flag});
            limit = std.fmt.parseInt(usize, limit_str, 10) catch return arg.showErr(
                usage,
                program,
                "`{s}` argument must be a positive integer",
                .{flag},
            );
        } else if (std.mem.eql(u8, flag, "-h")) {
            usage(stdout, program);
            return;
        } else return arg.showErr(usage, program, "unknown flag {s}", .{flag});
    }

    const in_path = opt_in_path orelse
        return arg.showErr(usage, program, "no input provided", .{});

    try machine.loadProgramFromFile(in_path);
    const err = machine.executeProgram(.{ .limit = limit });
    try machine.dumpStack(stdout);

    err catch |e| {
        std.debug.print("ERROR: {s}\n", .{bm.trapName(e)});
        std.process.exit(1);
    };
}
