const std = @import("std");

const Machine = @import("Machine.zig");
const Instruction = @import("instruction.zig").Instruction;

const program = [_]Instruction{
    .{ .Push = 69 },
    .{ .Push = 420 },
    .Plus,
    .{ .Push = 42 },
    .Minus,
    .{ .Push = 2 },
    .Mult,
    .{ .Push = 2 },
    .Div,
    .Halt,
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();
    var bm = Machine.init(&program);
    while (!bm.halt) {
        bm.executeInstruction() catch |e| {
            std.debug.print("ERROR: {s}\n", .{ @errorName(e) });
            try bm.dump(@TypeOf(stderr), stderr);
            std.process.exit(1);
        };
        try bm.dump(@TypeOf(stdout), stdout);
    }
}
