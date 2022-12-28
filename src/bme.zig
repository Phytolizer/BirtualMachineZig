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
    var i: usize = 0;
    while (i < bm.execution_limit and !machine.halt) : (i += 1) {
        machine.executeInst() catch |e| {
            std.debug.print("Trap activated: {s}\n", .{bm.trapName(e)});
            machine.dumpStack(std.io.getStdErr().writer()) catch unreachable;
            std.process.exit(1);
        };
    }
    try machine.dumpStack(stdout);
}
