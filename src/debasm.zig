const std = @import("std");
const bm = @import("bm.zig");
const arg = @import("arg.zig");
const io = @import("io.zig");

var machine = bm.Bm{};

pub fn main() void {
    run() catch std.process.exit(1);
}

fn out(comptime fmt: []const u8, args: anytype) void {
    std.io.getStdOut().writer().print(fmt ++ "\n", args) catch unreachable;
}

fn usage(_: anytype, program: []const u8) void {
    io.errLine("Usage: {s} <input.bm>", .{program});
}

fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();

    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    const program = args[0];

    if (args.len < 2) {
        return arg.showErr(usage, program, "ERROR: expected input\n", .{});
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
            => out("{s} {d}", .{ inst.kind.name(), inst.operand.as_i64 }),
        }
    }
}
