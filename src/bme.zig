const std = @import("std");
const bm = @import("bm.zig");

var machine = bm.Bm{};

pub fn main() void {
    run() catch std.process.exit(1);
}

fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();

    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <input.bm>\n", .{args[0]});
        std.debug.print("ERROR: expected input\n", .{});
        return error.Usage;
    }

    const in_path = args[1];

    try machine.loadProgramFromFile(in_path);
    const stdout = std.io.getStdOut().writer();
    const err = machine.executeProgram(.{ .limit = 69 });
    try machine.dumpStack(stdout);

    err catch |e| {
        std.debug.print("ERROR: {s}\n", .{bm.trapName(e)});
        std.process.exit(1);
    };
}
