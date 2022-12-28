const std = @import("std");
const bm = @import("bm.zig");

var machine = bm.Bm{};

pub fn main() void {
    run() catch std.process.exit(1);
}

fn out(comptime fmt: []const u8, args: anytype) void {
    std.io.getStdOut().writer().print(fmt ++ "\n", args) catch unreachable;
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

    for (machine.program[0..@intCast(usize, machine.program_size)]) |inst| {
        switch (inst.kind) {
            .nop,
            .plus,
            .minus,
            .mult,
            .div,
            .eq,
            .halt,
            .print_debug,
            => out("{s}", .{inst.kind.name()}),
            .push,
            .dup,
            .jmp,
            .jmp_if,
            => out("{s} {d}", .{ inst.kind.name(), inst.operand }),
        }
    }
}
