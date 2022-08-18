const std = @import("std");

const Machine = @import("Machine.zig");
const Instruction = @import("instruction.zig").Instruction;
const executionLimit = @import("defs.zig").executionLimit;

const program = [_]Instruction{
    .{ .Push = 0 },
    .{ .Push = 1 },
    .{ .Dup = 1 },
    .{ .Dup = 1 },
    .Plus,
    .{ .Jump = 2 },
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();
    var bm = try Machine.initFromMemory(&program);
    var i: usize = 0;
    while (i < executionLimit and !bm.halt) : (i += 1) {
        bm.executeInstruction() catch |e| {
            std.debug.print("ERROR: {s}\n", .{@errorName(e)});
            try bm.dumpStack(@TypeOf(stderr), stderr);
            std.process.exit(1);
        };
        try bm.dumpStack(@TypeOf(stdout), stdout);
    }
}
