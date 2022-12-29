const std = @import("std");
const bm = @import("bm.zig");
const arg = @import("arg.zig");
const str = @import("str.zig");

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

    const needsOperand = struct {
        fn needsOperand(token_it: *std.mem.TokenIterator(u8), inst: []const u8) ![]const u8 {
            return token_it.next() orelse {
                std.debug.print("ERROR: `{s}` requires an argument\n", .{inst});
                return error.Parse;
            };
        }
    }.needsOperand;

    if (std.mem.eql(u8, inst_name, "push")) {
        const operand_str = try needsOperand(&it, inst_name);
        const operand = std.fmt.parseInt(bm.Word, operand_str, 10) catch |e| {
            std.debug.print("ERROR: `{s}` is not a number\n", .{operand_str});
            return e;
        };
        result = bm.Inst.push(operand);
    } else if (std.mem.eql(u8, inst_name, "dup")) {
        const operand_str = try needsOperand(&it, inst_name);
        const operand = std.fmt.parseInt(bm.Word, operand_str, 10) catch |e| {
            std.debug.print("ERROR: `{s}` is not a number\n", .{operand_str});
            return e;
        };
        result = bm.Inst.dup(operand);
    } else if (std.mem.eql(u8, inst_name, "jmp")) {
        const operand_str = try needsOperand(&it, inst_name);
        const operand = 0;
        lt.pushDeferredOperand(machine.program_size, operand_str);
        result = bm.Inst.jmp(operand);
    } else if (std.mem.eql(u8, inst_name, "plus")) {
        result = bm.Inst.plus;
    } else if (std.mem.eql(u8, inst_name, "halt")) {
        result = bm.Inst.halt;
    } else {
        std.debug.print(
            "ERROR: `{s}` is not a valid instruction name\n",
            .{inst_name},
        );
        return error.Parse;
    }

    extraOperand: {
        if (it.next()) |extra| {
            if (extra[0] == '#')
                break :extraOperand;
            std.debug.print(
                "ERROR: too many arguments for `{s}`\n",
                .{inst_name},
            );
            return error.Parse;
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
            std.debug.print("ERROR: unknown jump to `{s}`\n", .{do.label_name});
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
