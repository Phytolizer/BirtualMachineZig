const std = @import("std");
const bm = @import("bm.zig");
const arg = @import("arg.zig");

var machine = bm.Bm{};

fn usage(writer: anytype, program: []const u8) void {
    writer.print(
        "Usage: {s} -i <input.bm> [-l <limit>]\n",
        .{program},
    ) catch unreachable;
}

pub fn main() void {
    run() catch std.process.exit(1);
}

fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();

    const args_buf = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args_buf);

    var args = args_buf;
    const program = arg.shift(&args) orelse unreachable;
    const stderr = std.io.getStdErr().writer();

    var opt_in_path: ?[]const u8 = null;
    var limit: ?usize = null;

    while (arg.shift(&args)) |flag| {
        if (std.mem.eql(u8, flag, "-i")) {
            opt_in_path = arg.shift(&args) orelse {
                usage(stderr, program);
                std.debug.print("ERROR: no argument provided for `{s}`\n", .{flag});
                return error.Usage;
            };
        } else if (std.mem.eql(u8, flag, "-l")) {
            const limit_str = arg.shift(&args) orelse {
                usage(stderr, program);
                std.debug.print("ERROR: no argument provided for `{s}`\n", .{flag});
                return error.Usage;
            };
            limit = std.fmt.parseInt(usize, limit_str, 10) catch {
                usage(stderr, program);
                std.debug.print("ERROR: `{s}` argument must be a positive integer\n", .{flag});
                return error.Usage;
            };
        } else {
            usage(stderr, program);
            std.debug.print("ERROR: unknown flag {s}\n", .{flag});
            return error.Usage;
        }
    }

    const in_path = opt_in_path orelse {
        usage(stderr, program);
        std.debug.print("ERROR: no input provided\n", .{});
        return error.Usage;
    };

    try machine.loadProgramFromFile(in_path);
    const stdout = std.io.getStdOut().writer();
    const err = machine.executeProgram(.{ .limit = limit });
    try machine.dumpStack(stdout);

    err catch |e| {
        std.debug.print("ERROR: {s}\n", .{bm.trapName(e)});
        std.process.exit(1);
    };
}
