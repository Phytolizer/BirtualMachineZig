const std = @import("std");
const defs = @import("defs.zig");

const Allocator = std.mem.Allocator;
const Instruction = @import("instruction.zig").Instruction;
const Word = defs.Word;

const stackCapacity = defs.stackCapacity;
const programCapacity = 1024;
const nativesCapacity = 1024;

const Self = @This();

pub const NativeError = error{
    StackUnderflow,
} || std.mem.Allocator.Error || std.fs.File.WriteError;

pub const Native = *const fn (bm: *Self) NativeError!void;

allocator: Allocator,
stack: [stackCapacity]Word = undefined,
stackSize: usize = 0,
program: [programCapacity]Instruction = undefined,
programSize: usize = 0,
ip: usize = 0,
halt: bool = false,
natives: [nativesCapacity]Native = undefined,
nativesSize: usize = 0,

pub fn initFromMemory(allocator: Allocator, program: []const Instruction) !Self {
    if (program.len > programCapacity) {
        return error.ProgramTooLong;
    }
    var result = Self{
        .allocator = allocator,
        .programSize = program.len,
    };
    std.mem.copy(Instruction, &result.program, program);
    return result;
}

pub fn initFromFile(allocator: Allocator, filePath: []const u8) !Self {
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
        .allocator = allocator,
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
            if (self.stackSize < @intCast(usize, distance)) {
                return error.StackUnderflow;
            }
            if (self.stackSize == stackCapacity) {
                return error.StackOverflow;
            }
            self.stack[self.stackSize] = self.stack[self.stackSize - 1 - @intCast(usize, distance)];
            self.stackSize += 1;
            self.ip += 1;
        },
        .Swap => |distance| {
            if (self.stackSize <= distance) {
                return error.StackUnderflow;
            }
            const a = self.stackSize - 1;
            const b = self.stackSize - 1 - @intCast(usize, distance);
            const t = self.stack[a];
            self.stack[a] = self.stack[b];
            self.stack[b] = t;
            self.ip += 1;
        },
        .Drop => {
            if (self.stackSize == 0) {
                return error.StackUnderflow;
            }
            self.stackSize -= 1;
            self.ip += 1;
        },
        .PlusI => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = @bitCast(Word, @bitCast(i64, self.stack[self.stackSize - 2]) +% @bitCast(i64, self.stack[self.stackSize - 1]));
            self.stackSize -= 1;
            self.ip += 1;
        },
        .MinusI => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = @bitCast(Word, @bitCast(i64, self.stack[self.stackSize - 2]) -% @bitCast(i64, self.stack[self.stackSize - 1]));
            self.stackSize -= 1;
            self.ip += 1;
        },
        .MultI => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = @bitCast(Word, @bitCast(i64, self.stack[self.stackSize - 2]) *% @bitCast(i64, self.stack[self.stackSize - 1]));
            self.stackSize -= 1;
            self.ip += 1;
        },
        .DivI => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            if (self.stack[self.stackSize - 1] == 0) {
                return error.DivisionByZero;
            }
            self.stack[self.stackSize - 2] = @bitCast(Word, @divExact(
                @bitCast(i64, self.stack[self.stackSize - 2]),
                @bitCast(i64, self.stack[self.stackSize - 1]),
            ));
            self.stackSize -= 1;
            self.ip += 1;
        },
        .PlusF => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = @bitCast(Word, @bitCast(f64, self.stack[self.stackSize - 2]) + @bitCast(f64, self.stack[self.stackSize - 1]));
            self.stackSize -= 1;
            self.ip += 1;
        },
        .MinusF => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = @bitCast(Word, @bitCast(f64, self.stack[self.stackSize - 2]) - @bitCast(f64, self.stack[self.stackSize - 1]));
            self.stackSize -= 1;
            self.ip += 1;
        },
        .MultF => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 2] = @bitCast(Word, @bitCast(f64, self.stack[self.stackSize - 2]) * @bitCast(f64, self.stack[self.stackSize - 1]));
            self.stackSize -= 1;
            self.ip += 1;
        },
        .DivF => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            if (self.stack[self.stackSize - 1] == 0) {
                return error.DivisionByZero;
            }
            self.stack[self.stackSize - 2] = @bitCast(Word, @bitCast(f64, self.stack[self.stackSize - 2]) / @bitCast(f64, self.stack[self.stackSize - 1]));
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
        .Ret => {
            if (self.stackSize < 1) {
                return error.StackUnderflow;
            }
            self.ip = @bitCast(usize, self.stack[self.stackSize - 1]);
            self.stackSize -= 1;
        },
        .Call => |dest| {
            if (self.stackSize == self.stack.len) {
                return error.StackOverflow;
            }
            self.stack[self.stackSize] = @bitCast(Word, self.ip + 1);
            self.stackSize += 1;
            self.ip = @bitCast(usize, dest);
        },
        .Native => |index| {
            if (index >= self.natives.len) {
                return error.IllegalOperand;
            }
            try self.natives[index](self);
            self.ip += 1;
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
        .GeF => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            const value = @bitCast(f64, self.stack[self.stackSize - 2]) >= @bitCast(f64, self.stack[self.stackSize - 1]);
            self.stack[self.stackSize - 2] = if (value) 1 else 0;
            self.stackSize -= 1;
            self.ip += 1;
        },
        .LtF => {
            if (self.stackSize < 2) {
                return error.StackUnderflow;
            }
            const value = @bitCast(f64, self.stack[self.stackSize - 2]) < @bitCast(f64, self.stack[self.stackSize - 1]);
            self.stack[self.stackSize - 2] = if (value) 1 else 0;
            self.stackSize -= 1;
            self.ip += 1;
        },
        .Not => {
            if (self.stackSize < 1) {
                return error.StackUnderflow;
            }
            self.stack[self.stackSize - 1] = if (self.stack[self.stackSize - 1] == 0) 1 else 0;
            self.ip += 1;
        },
        .Halt => {
            self.halt = true;
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
            try writer.print("  u64: {d} i64: {d} f64: {e:.6} ptr: 0x{x:0>16}\n", .{
                elem,
                @bitCast(i64, elem),
                @bitCast(f64, elem),
                elem,
            });
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

pub fn executeProgram(self: *Self, limit: ?usize) !void {
    var i: usize = 0;
    while ((limit == null or i < limit.?) and !self.halt) : (i += 1) {
        try self.executeInstruction();
    }
}

pub fn pushInstruction(self: *Self, inst: Instruction) !void {
    if (self.programSize == programCapacity) {
        return error.ProgramTooLong;
    }
    self.program[self.programSize] = inst;
    self.programSize += 1;
}

pub fn pushNative(self: *Self, native: Native) !void {
    if (self.nativesSize == nativesCapacity) {
        return error.TooManyNatives;
    }
    self.natives[self.nativesSize] = native;
    self.nativesSize += 1;
}

fn checkNative(value: anytype) void {
    std.debug.assert(@TypeOf(value) == Native);
}

pub fn alloc(self: *Self) NativeError!void {
    if (self.stackSize < 1) {
        return error.StackUnderflow;
    }
    const size = self.stack[self.stackSize - 1];
    var mem = try self.allocator.alloc(u8, @bitCast(usize, size));
    self.stack[self.stackSize - 1] = @bitCast(Word, @ptrToInt(mem.ptr));
}
comptime {
    checkNative(&alloc);
}

pub fn free(self: *Self) NativeError!void {
    if (self.stackSize < 1) {
        return error.StackUnderflow;
    }
    const ptr = @intToPtr([]u8, self.stack[self.stackSize - 1]);
    self.stackSize -= 1;
    self.allocator.free(ptr);
}
comptime {
    checkNative(&free);
}

pub fn printF64(self: *Self) NativeError!void {
    if (self.stackSize < 1) {
        return error.StackUnderflow;
    }
    const value = @bitCast(f64, self.stack[self.stackSize - 1]);
    self.stackSize -= 1;
    try std.io.getStdOut().writer().print("{d:.6}\n", .{value});
}
comptime {
    checkNative(&printF64);
}
