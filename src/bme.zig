const std = @import("std");
const libbm = @import("bm");

const Machine = libbm.Machine;

pub fn main() !void {
    var gpAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpAllocator.detectLeaks();
    const allocator = gpAllocator.backing_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <input.bm>\n", .{args[0]});
        std.debug.print("ERROR: expected input\n", .{});
        return error.InvalidUsage;
    }

    const inputFilePath = args[1];

    var bm = try Machine.initFromFile(inputFilePath);
    bm.executeProgram(69) catch |e| {
        const stderr = std.io.getStdErr().writer();
        try bm.dumpStack(@TypeOf(stderr), stderr);
        return e;
    };
    const stdout = std.io.getStdOut().writer();
    try bm.dumpStack(@TypeOf(stdout), stdout);
}
