const std = @import("std");
const defs = @import("defs.zig");

const Instruction = @import("instruction.zig").Instruction;
const Word = defs.Word;

const stackCapacity = defs.stackCapacity;

stack: [stackCapacity]Word = undefined,
stackSize: usize = 0,
program: []const Instruction,
ip: usize = 0,
halt: bool = false,

const Self = @This();

pub fn init(program: []const Instruction) Self {
    return Self{
        .program = program,
    };
}

pub fn executeInstruction(self: *Self) !void {
    const instruction = self.program[self.ip];
    switch (instruction) {
        .Push => |operand| {
            if (self.stackSize == stackCapacity) {
                return error.StackOverflow;
            }
            self.stack[self.stackSize] = operand;
            self.stackSize += 1;
            self.ip += 1;
        },
        .Plus => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = self.stack[self.stackSize - 2] + self.stack[self.stackSize - 1];
            self.stackSize -= 1;
            self.ip += 1;
        },
        .Minus => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = self.stack[self.stackSize - 2] - self.stack[self.stackSize - 1];
            self.stackSize -= 1;
            self.ip += 1;
        },
        .Mult => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = self.stack[self.stackSize - 2] * self.stack[self.stackSize - 1];
            self.stackSize -= 1;
            self.ip += 1;
        },
        .Div => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            if (self.stack[self.stackSize - 1] == 0) {
                return error.DivisionByZero;
            }
            self.stack[self.stackSize - 2] = @divExact(self.stack[self.stackSize - 2], self.stack[self.stackSize - 1]);
            self.stackSize -= 1;
            self.ip += 1;
        },
        .Jump => |dest| {
            self.ip = @intCast(usize, dest);
        },
        .Halt => {
            self.halt = true;
        },
    }
}

pub fn dump(self: *const Self, comptime Writer: type, writer: Writer) !void {
    comptime if (!@hasDecl(Writer, "print")) {
        @compileError("Writer does not have print method");
    };

    try writer.print("Stack:\n", .{});
    if (self.stackSize > 0) {
        for (self.stack[0..self.stackSize]) |elem| {
            try writer.print("  {d}\n", .{elem});
        }
    } else {
        try writer.print("  [empty]\n", .{});
    }
}
