const std = @import("std");

const Word = i64;

const Trap = error{
    StackOverflow,
    StackUnderflow,
    DivisionByZero,
    IllegalInstruction,
    IllegalInstructionAccess,
};

fn comptimeUncamel(comptime s: []const u8) []const u8 {
    var val: [32]u8 = undefined;
    var vi = 0;
    for (s) |c, j| {
        if (c >= 'A' and c <= 'Z') {
            if (j > 0) {
                val[vi] = ' ';
                vi += 1;
            }
            val[vi] = std.ascii.toLower(c);
            vi += 1;
        } else {
            val[vi] = c;
            vi += 1;
        }
    }
    return val[0..vi];
}

const trapNames = std.ComptimeStringMap([]const u8, blk: {
    const Kv = struct { []const u8, []const u8 };
    var result: [std.meta.fields(Trap).len]Kv = undefined;
    for (std.meta.fieldNames(Trap)) |n, i| {
        result[i] = .{ n, comptimeUncamel(n) };
    }
    break :blk result;
});
fn trapName(t: Trap) []const u8 {
    return trapNames.get(@errorName(t)).?;
}

fn toUpper(comptime s: []const u8) []const u8 {
    var result: [s.len]u8 = undefined;
    for (s) |c, i| {
        result[i] = std.ascii.toUpper(c);
    }
    return &result;
}
const instKindNames = blk: {
    var result: [std.meta.fields(Inst.Kind).len][]const u8 = undefined;
    for (std.meta.fields(Inst.Kind)) |f, i| {
        result[i] = "INST_" ++ toUpper(f.name);
    }
    break :blk result;
};

const Bm = struct {
    stack: [stack_capacity]Word = [_]Word{0} ** stack_capacity,
    stack_size: usize = 0,

    program: [program_capacity]Inst = undefined,
    program_size: usize = 0,
    ip: usize = 0,

    halt: bool = false,

    const stack_capacity = 1024;
    const program_capacity = 1024;

    fn pushInst(self: *@This(), inst: Inst) void {
        self.program[self.program_size] = inst;
        self.program_size += 1;
    }

    fn loadProgramFromMemory(self: *@This(), program: []const Inst) void {
        std.mem.copy(Inst, &self.program, program);
        self.program_size = program.len;
    }

    fn executeInst(self: *@This()) Trap!void {
        if (self.ip >= self.program_size)
            return Trap.IllegalInstructionAccess;

        const inst = self.program[self.ip];
        switch (inst.kind) {
            .push => {
                if (self.stack_size == stack_capacity)
                    return Trap.StackOverflow;
                self.stack[self.stack_size] = inst.operand;
                self.stack_size += 1;
                self.ip += 1;
            },
            .plus => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                self.stack[self.stack_size - 2] += self.stack[self.stack_size - 1];
                self.stack_size -= 1;
                self.ip += 1;
            },
            .minus => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                self.stack[self.stack_size - 2] -= self.stack[self.stack_size - 1];
                self.stack_size -= 1;
                self.ip += 1;
            },
            .mult => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                self.stack[self.stack_size - 2] *= self.stack[self.stack_size - 1];
                self.stack_size -= 1;
                self.ip += 1;
            },
            .div => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                if (self.stack[self.stack_size - 1] == 0)
                    return Trap.DivisionByZero;

                self.stack[self.stack_size - 2] = @divTrunc(
                    self.stack[self.stack_size - 2],
                    self.stack[self.stack_size - 1],
                );
                self.stack_size -= 1;
                self.ip += 1;
            },
            .jmp => self.ip = @intCast(usize, inst.operand),
            .halt => self.halt = true,
            _ => return Trap.IllegalInstruction,
        }
    }

    fn dumpStack(self: *const @This(), writer: anytype) !void {
        try writer.writeAll("Stack:\n");
        if (self.stack_size > 0) {
            var i: usize = 0;
            while (i < self.stack_size) : (i += 1) {
                try writer.print("  {d}\n", .{self.stack[i]});
            }
        } else try writer.writeAll("  [empty]\n");
    }
};

const Inst = struct {
    kind: Kind,
    operand: Word = 0,

    const Kind = enum(usize) {
        push,
        plus,
        minus,
        mult,
        div,
        jmp,
        halt,
        _,

        pub fn name(self: @This()) []const u8 {
            return instKindNames[@enumToInt(self)];
        }
    };

    fn push(operand: Word) @This() {
        return .{ .kind = .push, .operand = operand };
    }

    const plus = @This(){ .kind = .plus };
    const minus = @This(){ .kind = .minus };
    const mult = @This(){ .kind = .mult };
    const div = @This(){ .kind = .div };

    fn jmp(operand: Word) @This() {
        return .{ .kind = .jmp, .operand = operand };
    }

    const halt = @This(){ .kind = .halt };
};

var bm = Bm{};

pub fn main() !void {
    const program = [_]Inst{
        Inst.push(420),
        Inst.push(69),
        Inst.plus,
        Inst.push(42),
        Inst.minus,
        Inst.push(2),
        Inst.mult,
        Inst.push(4),
        Inst.div,
        Inst.halt,
    };

    bm.loadProgramFromMemory(&program);
    const stdout = std.io.getStdOut().writer();
    try bm.dumpStack(stdout);
    while (!bm.halt) {
        bm.executeInst() catch |e| {
            std.debug.print("Trap activated: {s}\n", .{trapName(e)});
            bm.dumpStack(std.io.getStdErr().writer()) catch unreachable;
            std.process.exit(1);
        };
        try bm.dumpStack(stdout);
    }
}
