const std = @import("std");

pub const Word = i64;

pub const limits = struct {
    pub const labels = 1024;
    pub const deferred_operands = 1024;
    pub const stack = 1024;
    pub const program = 1024;
};

pub const Label = struct {
    name: []const u8,
    address: Word,
};

pub const DeferredOperand = struct {
    address: Word,
    label_name: []const u8,
};

pub const LabelTable = struct {
    labels: [limits.labels]Label = undefined,
    labels_size: usize = 0,
    deferred_operands: [limits.deferred_operands]DeferredOperand = undefined,
    deferred_operands_size: usize = 0,

    pub fn findLabel(self: *const @This(), name: []const u8) ?*const Label {
        for (self.labels[0..self.labels_size]) |*label| {
            if (std.mem.eql(u8, label.name, name)) {
                return label;
            }
        }
        return null;
    }

    pub fn push(self: *@This(), name: []const u8, addr: Word) void {
        self.labels[self.labels_size] = .{ .name = name, .address = addr };
        self.labels_size += 1;
    }

    pub fn pushDeferredOperand(self: *@This(), addr: Word, label: []const u8) void {
        self.deferred_operands[self.deferred_operands_size] = .{
            .address = addr,
            .label_name = label,
        };
        self.deferred_operands_size += 1;
    }
};

pub const Trap = error{
    DivisionByZero,
    IllegalInstruction,
    IllegalInstructionAccess,
    IllegalOperand,
    StackOverflow,
    StackUnderflow,
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
pub fn trapName(t: Trap) []const u8 {
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
        result[i] = f.name;
    }
    break :blk result;
};

pub const Inst = struct {
    kind: Kind,
    operand: Word = 0,

    const Kind = enum(usize) {
        nop,
        push,
        plus,
        minus,
        mult,
        div,
        jmp,
        jmp_if,
        eq,
        halt,
        print_debug,
        dup,

        pub fn name(self: @This()) []const u8 {
            return instKindNames[@enumToInt(self)];
        }
    };

    pub const nop = @This(){ .kind = .nop };

    pub fn push(operand: Word) @This() {
        return .{ .kind = .push, .operand = operand };
    }

    pub const plus = @This(){ .kind = .plus };
    pub const minus = @This(){ .kind = .minus };
    pub const mult = @This(){ .kind = .mult };
    pub const div = @This(){ .kind = .div };

    pub fn jmp(operand: Word) @This() {
        return .{ .kind = .jmp, .operand = operand };
    }

    pub fn jmpIf(operand: Word) @This() {
        return .{ .kind = .jmp_if, .operand = operand };
    }

    pub const halt = @This(){ .kind = .halt };
    pub const printDebug = @This(){ .kind = .print_debug };
    pub fn dup(operand: Word) Inst {
        return .{ .kind = .dup, .operand = operand };
    }
};

pub const Bm = struct {
    stack: [limits.stack]Word = [_]Word{0} ** limits.stack,
    stack_size: Word = 0,

    program: [limits.program]Inst = undefined,
    program_size: Word = 0,
    ip: Word = 0,

    halt: bool = false,

    pub fn pushInst(self: *@This(), inst: Inst) void {
        self.program[@intCast(usize, self.program_size)] = inst;
        self.program_size += 1;
    }

    fn loadProgramFromMemory(self: *@This(), program: []const Inst) void {
        std.mem.copy(Inst, &self.program, program);
        self.program_size = @intCast(Word, program.len);
    }

    fn peek(self: *@This(), n: Word) Word {
        return self.stack[@intCast(usize, self.stack_size - n)];
    }

    fn peekMut(self: *@This(), n: usize) *Word {
        return &self.stack[@intCast(usize, self.stack_size) - n];
    }

    pub fn executeInst(self: *@This()) Trap!void {
        if (self.ip < 0 or self.ip >= self.program_size)
            return Trap.IllegalInstructionAccess;

        const inst = self.program[@intCast(usize, self.ip)];
        switch (inst.kind) {
            .nop => self.ip += 1,
            .push => {
                if (self.stack_size == limits.stack)
                    return Trap.StackOverflow;
                self.peekMut(0).* = inst.operand;
                self.stack_size += 1;
                self.ip += 1;
            },
            .plus => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                self.peekMut(2).* += self.peek(1);
                self.stack_size -= 1;
                self.ip += 1;
            },
            .minus => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                self.peekMut(2).* -= self.peek(1);
                self.stack_size -= 1;
                self.ip += 1;
            },
            .mult => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                self.peekMut(2).* *= self.peek(1);
                self.stack_size -= 1;
                self.ip += 1;
            },
            .div => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                if (self.peek(1) == 0)
                    return Trap.DivisionByZero;

                self.peekMut(2).* = @divTrunc(self.peek(2), self.peek(1));
                self.stack_size -= 1;
                self.ip += 1;
            },
            .jmp => self.ip = inst.operand,
            .eq => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;

                self.peekMut(2).* = @boolToInt(self.peek(2) == self.peek(1));
                self.stack_size -= 1;
                self.ip += 1;
            },
            .jmp_if => {
                if (self.stack_size < 1)
                    return Trap.StackUnderflow;

                if (self.peek(1) != 0)
                    self.ip = inst.operand
                else
                    self.ip += 1;

                self.stack_size -= 1;
            },
            .print_debug => {
                if (self.stack_size < 1)
                    return Trap.StackUnderflow;

                std.debug.print("{d}\n", .{self.peek(1)});
                self.ip += 1;
            },
            .halt => self.halt = true,
            .dup => {
                if (self.stack_size - inst.operand <= 0)
                    return Trap.StackUnderflow;
                if (inst.operand < 0)
                    return Trap.IllegalOperand;

                self.peekMut(0).* = self.peek(inst.operand + 1);
                self.stack_size += 1;
                self.ip += 1;
            },
        }
    }

    pub const ExecuteArgs = struct {
        limit: ?usize = null,
    };

    pub fn executeProgram(self: *@This(), args: ExecuteArgs) Trap!void {
        var i: usize = 0;
        while ((args.limit == null or i < args.limit.?) and !self.halt) : (i += 1) {
            try self.executeInst();
        }
    }

    pub fn dumpStack(self: *const @This(), writer: anytype) !void {
        try writer.writeAll("Stack:\n");
        if (self.stack_size > 0) {
            var i: usize = 0;
            while (i < self.stack_size) : (i += 1) {
                try writer.print("  {d}\n", .{self.stack[i]});
            }
        } else try writer.writeAll("  [empty]\n");
    }

    pub fn loadProgramFromFile(self: *@This(), file_path: []const u8) !void {
        var f = try std.fs.cwd().openFile(file_path, .{});
        defer f.close();

        const stat = try f.stat();
        const m = stat.size;
        const n_insts = @divExact(m, @sizeOf(Inst));
        _ = try f.readAll(std.mem.sliceAsBytes(self.program[0..n_insts]));
        self.program_size = @intCast(Word, n_insts);
    }

    pub fn saveProgramToFile(self: *const @This(), file_path: []const u8) !void {
        var f = try std.fs.cwd().createFile(file_path, .{});
        defer f.close();

        try f.writeAll(std.mem.sliceAsBytes(
            self.program[0..@intCast(usize, self.program_size)],
        ));
    }
};

pub var machine = Bm{};
pub var lt = LabelTable{};
