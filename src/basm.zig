const std = @import("std");
const bm = @import("bm.zig");
const arg = @import("arg.zig");

var machine = bm.Bm{};

fn translateLine(line: []const u8) !bm.Inst {
    var it = std.mem.tokenize(u8, line, &std.ascii.whitespace);
    const inst_name = it.next() orelse
        // TODO
        unreachable;

    if (std.mem.eql(u8, inst_name, "push")) {
        const operand_str = it.next() orelse
            // TODO
            unreachable;
        const operand = std.fmt.parseInt(bm.Word, operand_str, 10) catch |e| {
            std.debug.print("ERROR: `{s}` is not a number\n", .{operand_str});
            return e;
        };
        return bm.Inst.push(operand);
    }
    if (std.mem.eql(u8, inst_name, "dup")) {
        const operand_str = it.next() orelse
            // TODO
            unreachable;
        const operand = std.fmt.parseInt(bm.Word, operand_str, 10) catch |e| {
            std.debug.print("ERROR: `{s}` is not a number\n", .{operand_str});
            return e;
        };
        return bm.Inst.dup(operand);
    }
    if (std.mem.eql(u8, inst_name, "jmp")) {
        const operand_str = it.next() orelse
            // TODO
            unreachable;
        const operand = std.fmt.parseInt(bm.Word, operand_str, 10) catch |e| {
            std.debug.print("ERROR: `{s}` is not a number\n", .{operand_str});
            return e;
        };
        return bm.Inst.jmp(operand);
    }
    if (std.mem.eql(u8, inst_name, "plus"))
        return bm.Inst.plus;
    if (std.mem.eql(u8, inst_name, "halt"))
        return bm.Inst.halt;
    std.debug.print(
        "ERROR: `{s}` is not a valid instruction name\n",
        .{inst_name},
    );
    return error.Parse;
}

fn translateAsm(source: []const u8, program: []bm.Inst) !bm.Word {
    var source_iter = std.mem.tokenize(u8, source, "\r\n");
    var program_size: usize = 0;
    while (source_iter.next()) |line| : (program_size += 1) {
        program[program_size] = try translateLine(line);
    }
    return @intCast(bm.Word, program_size);
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
    machine.program_size = try translateAsm(source_code, &machine.program);
    try machine.saveProgramToFile(out_path);
}
