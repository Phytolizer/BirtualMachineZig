const std = @import("std");
const libbm = @import("bm");

const Machine = libbm.Machine;
const Instruction = libbm.instruction.Instruction;

pub fn main() !void {
    var gpAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpAllocator.detectLeaks();
    const allocator = gpAllocator.backing_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 2) {
        std.debug.print("Usage: {s} <input.bm>\n", .{args[0]});
        std.debug.print("ERROR: no input provided\n", .{});
        return error.InvalidUsage;
    }

    const inputFilePath = args[1];
    var bm = try Machine.initFromFile(inputFilePath);

    const stdout = std.io.getStdOut().writer();

    for (bm.program[0..bm.programSize]) |inst| {
        try stdout.print("{s}", .{Instruction.name(inst)});
        if (inst.operand()) |operand| {
            try stdout.print(" {d}", .{operand});
        }
        try stdout.writeAll("\n");
    }
}
