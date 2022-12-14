const std = @import("std");
const bm = @import("bm.zig");
const arg = @import("arg.zig");
const str = @import("str.zig");
const io = @import("io.zig");

fn translateLine(
    machine: *const bm.Bm,
    basm: *bm.Basm,
    line: []const u8,
) !?bm.Inst {
    var it = std.mem.tokenize(u8, line, &std.ascii.whitespace);
    var inst_name = it.next() orelse return null;
    if (inst_name[0] == '#') return null;

    if (str.charBeforeEnd(inst_name, 1) == ':') {
        // label
        basm.push(str.beforeEnd(inst_name, 1), machine.program_size);
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
        fn f(token_it: *std.mem.TokenIterator(u8), inst: []const u8) !i64 {
            const s = try needsOperand(token_it, inst);
            return std.fmt.parseInt(i64, s, 10) catch
                return parseErr("`{s}` is not a number", .{s});
        }
    }.f;

    if (std.mem.eql(u8, inst_name, "jmp")) {
        const operand = try needsOperand(&it, inst_name);
        if (std.fmt.parseInt(u64, operand, 10)) |operand_num| {
            result = bm.Inst.jmp(.{ .as_u64 = operand_num });
        } else |_| {
            basm.pushDeferredOperand(machine.program_size, operand);
            result = bm.Inst.jmp(.{ .as_u64 = 0 });
        }
    } else findDef: {
        inline for (std.meta.fields(bm.Inst.Kind)) |fld| {
            const getVal = struct {
                const Error = error{Parse};
                fn f(comptime hasOperand: bool) fn (
                    token_it: *std.mem.TokenIterator(u8),
                    name: []const u8,
                ) Error!bm.Inst {
                    return if (hasOperand)
                        struct {
                            fn g(
                                token_it: *std.mem.TokenIterator(u8),
                                name: []const u8,
                            ) Error!bm.Inst {
                                const operand = try needsNumberOperand(token_it, name);
                                return @field(bm.Inst, fld.name)(.{ .as_i64 = operand });
                            }
                        }.g
                    else
                        struct {
                            fn g(
                                _: *std.mem.TokenIterator(u8),
                                _: []const u8,
                            ) Error!bm.Inst {
                                return @field(bm.Inst, fld.name);
                            }
                        }.g;
                }
            }.f;
            if (std.mem.eql(u8, inst_name, fld.name)) {
                const k = @field(bm.Inst.Kind, fld.name);
                result = try getVal(k.hasOperand())(&it, inst_name);
                break :findDef;
            }
        }

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

fn translateAsm(source: []const u8, machine: *bm.Bm, basm: *bm.Basm) !void {
    machine.program_size = 0;
    var source_iter = std.mem.tokenize(u8, source, "\r\n");
    while (source_iter.next()) |line| {
        machine.pushInst(try translateLine(machine, basm, line) orelse continue);
    }

    for (basm.deferred_operands[0..basm.deferred_operands_size]) |do| {
        if (basm.findLabel(do.label_name)) |label| {
            machine.program[@intCast(usize, do.address)].operand.as_u64 = label.address;
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
    try translateAsm(source_code, &bm.machine, &bm.basm);
    try bm.machine.saveProgramToFile(out_path);
}
