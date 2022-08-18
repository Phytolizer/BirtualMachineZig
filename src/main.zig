const std = @import("std");

const Machine = @import("Machine.zig");
const Instruction = @import("instruction.zig").Instruction;

const program = [_]Instruction{
    .{ .Push = 69 },
    .{ .Push = 420 },
    .Plus,
    .Plus,
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bm = Machine{};
    for (program) |instruction| {
        bm.executeInstruction(instruction) catch |e| {
            std.debug.print("ERROR: {s} at {s}\n", .{@errorName(e), @tagName(instruction)});
            try bm.dump(@TypeOf(stdout), stdout);
            std.process.exit(1);
        };
    }
}
