const std = @import("std");
const defs = @import("defs.zig");

const Instruction = @import("instruction.zig").Instruction;
const Word = defs.Word;

const stackCapacity = defs.stackCapacity;
const programCapacity = 1024;

stack: [stackCapacity]Word = undefined,
stackSize: usize = 0,
program: [programCapacity]Instruction = undefined,
programSize: usize = 0,
ip: Word = 0,
halt: bool = false,

const Self = @This();

pub fn initFromMemory(program: []const Instruction) !Self {
    if (program.len > programCapacity) {
        return error.ProgramTooLong;
    }
    var result = Self{
        .programSize = program.len,
    };
    std.mem.copy(Instruction, &result.program, program);
    return result;
}

pub fn initFromFile(filePath: []const u8) !Self {
    var file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();
    const stat = try file.stat();
    if (stat.size % @sizeOf(Instruction) != 0) {
        return error.InvalidProgramFile;
    }
    if (stat.size > programCapacity * @sizeOf(Instruction)) {
        return error.ProgramTooLong;
    }

    var result = Self{
        .programSize = stat.size / @sizeOf(Instruction),
    };

    const nread = try file.read(@ptrCast([*]u8, &result.program)[0..stat.size]);
    if (nread != stat.size) {
        return error.IOFailed;
    }

    return result;
}

pub fn executeInstruction(self: *Self) !void {
    if (self.ip < 0 or self.ip >= self.programSize) {
        return error.IllegalAccess;
    }
    const instruction = self.program[@intCast(usize, self.ip)];
    switch (instruction) {
        .Nop => {
            self.ip += 1;
        },
        .Push => |operand| {
            if (self.stackSize == stackCapacity) {
                return error.StackOverflow;
            }
            self.stack[self.stackSize] = operand;
            self.stackSize += 1;
            self.ip += 1;
        },
        .Dup => |distance| {
            if (distance < 0) {
                return error.IllegalOperand;
            }
            if (self.stackSize - @intCast(usize, distance) < 0) {
                return error.StackUnderflow;
            }
            if (self.stackSize == stackCapacity) {
                return error.StackOverflow;
            }
            self.stack[self.stackSize] = self.stack[self.stackSize - 1 - @intCast(usize, distance)];
            self.stackSize += 1;
            self.ip += 1;
        },
        .Plus => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = self.stack[self.stackSize - 2] +% self.stack[self.stackSize - 1];
            self.stackSize -= 1;
            self.ip += 1;
        },
        .Minus => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = self.stack[self.stackSize - 2] -% self.stack[self.stackSize - 1];
            self.stackSize -= 1;
            self.ip += 1;
        },
        .Mult => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = self.stack[self.stackSize - 2] *% self.stack[self.stackSize - 1];
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
            self.ip = dest;
        },
        .JumpIf => |dest| {
            if (self.stackSize < 1) {
                return error.StackUnderflow;
            }
            if (self.stack[self.stackSize - 1] != 0) {
                self.ip = dest;
            } else {
                self.ip += 1;
            }
            self.stackSize -= 1;
        },
        .Eq => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            const value = self.stack[self.stackSize - 2] == self.stack[self.stackSize - 1];
            self.stack[self.stackSize - 2] = if (value) 1 else 0;
            self.stackSize -= 1;
            self.ip += 1;
        },
        .Halt => {
            self.halt = true;
        },
        .PrintDebug => {
            if (self.stackSize < 1) {
                return error.StackUnderflow;
            }
            std.debug.print("{d}\n", .{self.stack[self.stackSize - 1]});
            self.stackSize -= 1;
            self.ip += 1;
        },
    }
}

pub fn dumpStack(self: *const Self, comptime Writer: type, writer: Writer) !void {
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

pub fn saveProgramToFile(self: *const Self, filePath: []const u8) !void {
    var file = try std.fs.cwd().createFile(filePath, .{});
    defer file.close();

    try file.writeAll(@ptrCast([*]const u8, &self.program[0])[0..(self.programSize * @sizeOf(Instruction))]);
}