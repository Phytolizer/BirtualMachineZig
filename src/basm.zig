const std = @import("std");
const bm = @import("bm.zig");
const arg = @import("arg.zig");
const str = @import("str.zig");
const io = @import("io.zig");

fn translateLine(
    machine: *const bm.Bm,
    lt: *bm.LabelTable,
    line: []const u8,
) !?bm.Inst {
    var it = std.mem.tokenize(u8, line, &std.ascii.whitespace);
    var inst_name = it.next() orelse return null;
    if (inst_name[0] == '#') return null;

    if (str.charBeforeEnd(inst_name, 1) == ':') {
        // label
        lt.push(str.beforeEnd(inst_name, 1), machine.program_size);
        inst_name = it.next() orelse return null;
    }

    var result: bm.Inst = undefined;

    const parseErr = struct {
        fn f(comptime fmt: []const u8, args: anytype) error{Parse} {
            io.showErr(fmt, args);
            return error.Parse;
        }
    }.f;

    const needsOperand = struct {
        fn needsOperand(token_it: *std.mem.TokenIterator(u8), inst: []const u8) ![]const u8 {
            return token_it.next() orelse
                return parseErr("`{s}` requires an argument", .{inst});
        }
    }.needsOperand;
    const needsNumberOperand = struct {
        fn f(token_it: *std.mem.TokenIterator(u8), inst: []const u8) !bm.Word {
            const s = try needsOperand(token_it, inst);
            return std.fmt.parseInt(bm.Word, s, 10) catch
                return parseErr("`{s}` is not a number", .{s});
        }
    }.f;

    if (std.mem.eql(u8, inst_name, "push")) {
        const operand = try needsNumberOperand(&it, inst_name);
        result = bm.Inst.push(operand);
    } else if (std.mem.eql(u8, inst_name, "dup")) {
        const operand = try needsNumberOperand(&it, inst_name);
        result = bm.Inst.dup(operand);
    } else if (std.mem.eql(u8, inst_name, "jmp")) {
        const operand = try needsOperand(&it, inst_name);
        if (std.fmt.parseInt(bm.Word, operand, 10)) |operand_num| {
            result = bm.Inst.jmp(operand_num);
        } else |_| {
            lt.pushDeferredOperand(machine.program_size, operand);
            result = bm.Inst.jmp(0);
        }
    } else if (std.mem.eql(u8, inst_name, "plus")) {
        result = bm.Inst.plus;
    } else if (std.mem.eql(u8, inst_name, "halt")) {
        result = bm.Inst.halt;
    } else {
        return parseErr("`{s}` is not a valid instruction name", .{inst_name});
    }

    extraOperand: {
        if (it.next()) |extra| {
            if (extra[0] == '#')
                break :extraOperand;
            return parseErr("too many arguments for `{s}`", .{inst_name});
        }
    }

    return result;
}

fn translateAsm(source: []const u8, machine: *bm.Bm, lt: *bm.LabelTable) !void {
    machine.program_size = 0;
    var source_iter = std.mem.tokenize(u8, source, "\r\n");
    while (source_iter.next()) |line| {
        machine.pushInst(try translateLine(machine, lt, line) orelse continue);
    }

    for (lt.deferred_operands[0..lt.deferred_operands_size]) |do| {
        if (lt.findLabel(do.label_name)) |label| {
            machine.program[@intCast(usize, do.address)].operand = label.address;
        } else {
            io.showErr("unknown jump to `{s}`", .{do.label_name});
            return error.UnknownLabel;
        }
    }
}

pub fn main() void {
    run() catch std.process.exit(1);
}

fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const a = gpa.allocator();

    const args_buf = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args_buf);

    const usage = arg.genUsage("<input.basm> <output.bm>");

    var args = args_buf;
    const program = arg.shift(&args) orelse unreachable;

    const in_path = arg.shift(&args) orelse
        return arg.showErr(usage, program, "expected input", .{});

    const out_path = arg.shift(&args) orelse
        return arg.showErr(usage, program, "expected output", .{});

    const source_code = try std.fs.cwd().readFileAlloc(
        a,
        in_path,
        std.math.maxInt(usize),
    );
    defer a.free(source_code);
    try translateAsm(source_code, &bm.machine, &bm.lt);
    try bm.machine.saveProgramToFile(out_path);
}
