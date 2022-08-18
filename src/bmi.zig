const std = @import("std");
const libbm = @import("bm");
const defs = libbm.defs;

const Machine = libbm.Machine;

pub fn main() !void {
    var gpAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpAllocator.backing_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <input.bm>\n", .{args[0]});
        std.debug.print("ERROR: expected input\n", .{});
        return error.InvalidUsage;
    }

    const inputFilePath = args[1];

    const stderr = std.io.getStdErr().writer();
    const stdout = std.io.getStdOut().writer();

    var bm = try Machine.initFromFile(inputFilePath);
    var i: usize = 0;
    while (i < defs.executionLimit and !bm.halt) : (i += 1) {
        bm.executeInstruction() catch |e| {
            std.debug.print("ERROR: {s}\n", .{@errorName(e)});
            try bm.dumpStack(@TypeOf(stderr), stderr);
            return e;
        };
        try bm.dumpStack(@TypeOf(stdout), stdout);
    }

    if (gpAllocator.detectLeaks()) {
        return error.LeakedMemory;
    }
}
