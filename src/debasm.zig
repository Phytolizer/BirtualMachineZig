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
        std.debug.print("ERROR: no input provided\n", .{});
        return error.InvalidUsage;
    }

    const inputFilePath = args[1];
    var bm = try Machine.initFromFile(inputFilePath);

    const stdout = std.io.getStdOut().writer();

    var i: usize = 0;
    while (i < bm.programSize) : (i += 1) {
        switch (bm.program[i]) {
            .Nop => {
                try stdout.writeAll("nop\n");
            },
            .Push => |operand| {
                try stdout.print("push {d}\n", .{operand});
            },
            .Dup => |operand| {
                try stdout.print("dup {d}\n", .{operand});
            },
            .Plus => {
                try stdout.writeAll("plus\n");
            },
            .Minus => {
                try stdout.writeAll("minus\n");
            },
            .Mult => {
                try stdout.writeAll("mult\n");
            },
            .Div => {
                try stdout.writeAll("div\n");
            },
            .Jump => |operand| {
                try stdout.print("jmp {d}\n", .{operand});
            },
            .JumpIf => |operand| {
                try stdout.print("jmp_if {d}\n", .{operand});
            },
            .Eq => {
                try stdout.writeAll("eq\n");
            },
            .Halt => {
                try stdout.writeAll("halt\n");
            },
            .PrintDebug => {
                try stdout.writeAll("print_debug\n");
            },
        }
    }
}
