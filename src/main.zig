const std = @import("std");

const Word = i64;

const Trap = error{
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

const Inst = struct {
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
        _,

        pub fn name(self: @This()) []const u8 {
            return instKindNames[@enumToInt(self)];
        }
    };

    const nop = @This(){ .kind = .nop };

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

    fn jmpIf(operand: Word) @This() {
        return .{ .kind = .jmp_if, .operand = operand };
    }

    const halt = @This(){ .kind = .halt };
    const printDebug = @This(){ .kind = .print_debug };
    fn dup(operand: Word) Inst {
        return .{ .kind = .dup, .operand = operand };
    }
};

const Bm = struct {
    stack: [stack_capacity]Word = [_]Word{0} ** stack_capacity,
    stack_size: Word = 0,

    program: [program_capacity]Inst = undefined,
    program_size: Word = 0,
    ip: Word = 0,

    halt: bool = false,

    const stack_capacity = 1024;
    const program_capacity = 1024;

    fn pushInst(self: *@This(), inst: Inst) void {
        self.program[self.program_size] = inst;
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

    fn executeInst(self: *@This()) Trap!void {
        if (self.ip < 0 or self.ip >= self.program_size)
            return Trap.IllegalInstructionAccess;

        const inst = self.program[@intCast(usize, self.ip)];
        switch (inst.kind) {
            .nop => self.ip += 1,
            .push => {
                if (self.stack_size == stack_capacity)
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

    fn loadProgramFromFile(self: *@This(), file_path: []const u8) !void {
        var f = try std.fs.cwd().openFile(file_path, .{});
        defer f.close();

        const stat = try f.stat();
        const m = stat.size;
        const n_insts = @divExact(m, @sizeOf(Inst));
        _ = try f.readAll(std.mem.sliceAsBytes(self.program[0..n_insts]));
        self.program_size = @intCast(Word, n_insts);
    }

    fn saveProgramToFile(self: *const @This(), file_path: []const u8) !void {
        var f = try std.fs.cwd().createFile(file_path, .{});
        defer f.close();

        try f.writeAll(std.mem.sliceAsBytes(
            self.program[0..@intCast(usize, self.program_size)],
        ));
    }
};

var bm = Bm{};

const execution_limit = 100;

fn translateLine(line: []const u8) !Inst {
    var it = std.mem.tokenize(u8, line, &std.ascii.whitespace);
    const inst_name = it.next() orelse
        // TODO
        unreachable;

    if (std.mem.eql(u8, inst_name, "push")) {
        const operand_str = it.next() orelse
            // TODO
            unreachable;
        const operand = std.fmt.parseInt(Word, operand_str, 10) catch |e| {
            std.debug.print("ERROR: `{s}` is not a number\n", .{operand_str});
            return e;
        };
        return Inst.push(operand);
    }
    if (std.mem.eql(u8, inst_name, "dup")) {
        const operand_str = it.next() orelse
            // TODO
            unreachable;
        const operand = std.fmt.parseInt(Word, operand_str, 10) catch |e| {
            std.debug.print("ERROR: `{s}` is not a number\n", .{operand_str});
            return e;
        };
        return Inst.dup(operand);
    }
    if (std.mem.eql(u8, inst_name, "jmp")) {
        const operand_str = it.next() orelse
            // TODO
            unreachable;
        const operand = std.fmt.parseInt(Word, operand_str, 10) catch |e| {
            std.debug.print("ERROR: `{s}` is not a number\n", .{operand_str});
            return e;
        };
        return Inst.jmp(operand);
    }
    if (std.mem.eql(u8, inst_name, "plus")) {
        return Inst.plus;
    }
    std.debug.print(
        "ERROR: `{s}` is not a valid instruction name\n",
        .{inst_name},
    );
    return error.Parse;
}

fn translateAsm(source: []const u8, program: []Inst) !Word {
    var source_iter = std.mem.tokenize(u8, source, "\r\n");
    var program_size: usize = 0;
    while (source_iter.next()) |line| : (program_size += 1) {
        program[program_size] = try translateLine(line);
    }
    return @intCast(Word, program_size);
}

pub fn main() void {
    run() catch std.process.exit(1);
}

fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();

    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} <input.basm> <output.bm>", .{args[0]});
        return error.Usage;
    }

    const in_path = args[1];
    const out_path = args[2];

    const source_code = try std.fs.cwd().readFileAlloc(
        a,
        in_path,
        std.math.maxInt(usize),
    );
    defer a.free(source_code);
    bm.program_size = try translateAsm(source_code, &bm.program);
    const stdout = std.io.getStdOut().writer();
    var i: usize = 0;
    while (i < execution_limit and !bm.halt) : (i += 1) {
        bm.executeInst() catch |e| {
            std.debug.print("Trap activated: {s}\n", .{trapName(e)});
            bm.dumpStack(std.io.getStdErr().writer()) catch unreachable;
            std.process.exit(1);
        };
    }
    try bm.dumpStack(stdout);

    try bm.saveProgramToFile(out_path);
}
