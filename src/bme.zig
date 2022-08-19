const std = @import("std");
const libbm = @import("bm");

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

    var bm = try Machine.initFromFile(inputFilePath);
    try bm.executeProgram(69);

    if (gpAllocator.detectLeaks()) {
        return error.LeakedMemory;
    }
}
