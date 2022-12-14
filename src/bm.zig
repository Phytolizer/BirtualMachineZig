const std = @import("std");

const InstAddr = u64;

pub const Word = packed union {
    as_u64: u64,
    as_i64: i64,
    as_f64: f64,
    as_ptr: ?*anyopaque,
};

comptime {
    std.debug.assert(@bitSizeOf(Word) == 64);
}

pub const limits = struct {
    pub const labels = 1024;
    pub const deferred_operands = 1024;
    pub const stack = 1024;
    pub const program = 1024;
};

pub const Label = struct {
    name: []const u8,
    address: InstAddr,
};

pub const DeferredOperand = struct {
    address: InstAddr,
    label_name: []const u8,
};

pub const Basm = struct {
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

    pub fn push(self: *@This(), name: []const u8, addr: InstAddr) void {
        self.labels[self.labels_size] = .{ .name = name, .address = addr };
        self.labels_size += 1;
    }

    pub fn pushDeferredOperand(
        self: *@This(),
        addr: InstAddr,
        label: []const u8,
    ) void {
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
    operand: Word = .{ .as_u64 = 0 },

    pub const Kind = enum(usize) {
        nop,
        push,
        plusi,
        minusi,
        multi,
        divi,
        jmp,
        jmp_if,
        eq,
        halt,
        print_debug,
        dup,

        pub fn name(self: @This()) []const u8 {
            return instKindNames[@enumToInt(self)];
        }

        pub fn hasOperand(comptime self: @This()) bool {
            return switch (self) {
                .push, .dup, .jmp, .jmp_if => true,
                else => false,
            };
        }
    };

    pub const nop = @This(){ .kind = .nop };

    pub fn push(operand: Word) @This() {
        return .{ .kind = .push, .operand = operand };
    }

    pub const plusi = @This(){ .kind = .plusi };
    pub const minusi = @This(){ .kind = .minusi };
    pub const multi = @This(){ .kind = .multi };
    pub const divi = @This(){ .kind = .divi };
    pub const eq = @This(){ .kind = .eq };

    pub fn jmp(operand: Word) @This() {
        return .{ .kind = .jmp, .operand = operand };
    }

    pub fn jmp_if(operand: Word) @This() {
        return .{ .kind = .jmp_if, .operand = operand };
    }

    pub const halt = @This(){ .kind = .halt };
    pub const print_debug = @This(){ .kind = .print_debug };
    pub fn dup(operand: Word) Inst {
        return .{ .kind = .dup, .operand = operand };
    }
};

pub const Bm = struct {
    stack: [limits.stack]Word = undefined,
    stack_size: u64 = 0,

    program: [limits.program]Inst = undefined,
    program_size: u64 = 0,
    ip: InstAddr = 0,

    halt: bool = false,

    pub fn pushInst(self: *@This(), inst: Inst) void {
        self.program[@intCast(usize, self.program_size)] = inst;
        self.program_size += 1;
    }

    fn loadProgramFromMemory(self: *@This(), program: []const Inst) void {
        std.mem.copy(Inst, &self.program, program);
        self.program_size = @intCast(Word, program.len);
    }

    fn peek(self: *@This(), n: usize) Word {
        return self.stack[@intCast(usize, self.stack_size - n)];
    }

    fn peekMut(self: *@This(), n: usize) *Word {
        return &self.stack[@intCast(usize, self.stack_size) - n];
    }

    pub fn executeInst(self: *@This()) Trap!void {
        if (self.ip >= self.program_size)
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
            .plusi => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                self.peekMut(2).as_u64 += self.peek(1).as_u64;
                self.stack_size -= 1;
                self.ip += 1;
            },
            .minusi => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                self.peekMut(2).as_u64 -= self.peek(1).as_u64;
                self.stack_size -= 1;
                self.ip += 1;
            },
            .multi => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                self.peekMut(2).as_u64 *= self.peek(1).as_u64;
                self.stack_size -= 1;
                self.ip += 1;
            },
            .divi => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;
                if (self.peek(1).as_u64 == 0)
                    return Trap.DivisionByZero;

                self.peekMut(2).as_u64 = @divTrunc(
                    self.peek(2).as_u64,
                    self.peek(1).as_u64,
                );
                self.stack_size -= 1;
                self.ip += 1;
            },
            .jmp => self.ip = inst.operand.as_u64,
            .eq => {
                if (self.stack_size < 2)
                    return Trap.StackUnderflow;

                self.peekMut(2).as_u64 = @boolToInt(
                    self.peek(2).as_u64 == self.peek(1).as_u64,
                );
                self.stack_size -= 1;
                self.ip += 1;
            },
            .jmp_if => {
                if (self.stack_size < 1)
                    return Trap.StackUnderflow;

                if (self.peek(1).as_u64 != 0)
                    self.ip = inst.operand.as_u64
                else
                    self.ip += 1;

                self.stack_size -= 1;
            },
            .print_debug => {
                if (self.stack_size < 1)
                    return Trap.StackUnderflow;

                std.debug.print("{d}\n", .{self.peek(1).as_u64});
                self.ip += 1;
            },
            .halt => self.halt = true,
            .dup => {
                if (self.stack_size <= inst.operand.as_u64)
                    return Trap.StackUnderflow;

                self.peekMut(0).* = self.peek(inst.operand.as_u64 + 1);
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
                try writer.print(
                    "  u64: {d}, i64: {d}, f64: {d:.6}, ptr: 0x{X:0>16}\n",
                    .{
                        self.stack[i].as_u64,
                        self.stack[i].as_i64,
                        self.stack[i].as_f64,
                        @ptrToInt(self.stack[i].as_ptr),
                    },
                );
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
        self.program_size = @intCast(InstAddr, n_insts);
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
pub var basm = Basm{};
