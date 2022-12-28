const std = @import("std");
const bm = @import("bm.zig");
const arg = @import("arg.zig");

var machine = bm.Bm{};

fn usage(writer: anytype, program: []const u8) void {
    writer.print("Usage: {s} <input.bm>\n", .{program}) catch unreachable;
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

    const in_path = arg.shift(&args) orelse {
        usage(stderr, program);
        std.debug.print("ERROR: expected input\n", .{});
        return error.Usage;
    };

    try machine.loadProgramFromFile(in_path);
    const stdout = std.io.getStdOut().writer();
    const err = machine.executeProgram(.{ .limit = 69 });
    try machine.dumpStack(stdout);

    err catch |e| {
        std.debug.print("ERROR: {s}\n", .{bm.trapName(e)});
        std.process.exit(1);
    };
}
