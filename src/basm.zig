const std = @import("std");
const libbm = @import("bm");
const args = @import("args");
const defs = libbm.defs;
const string = libbm.string;
const file = libbm.file;

const Allocator = std.mem.Allocator;
const Machine = libbm.Machine;
const Instruction = libbm.instruction.Instruction;
const Word = defs.Word;
const InstAddr = defs.InstAddr;

const DeferredOperand = struct {
    address: InstAddr,
    label: []const u8,
};

const Label = struct {
    name: []const u8,
    address: InstAddr,
};

const AssemblerContext = struct {
    labels: std.ArrayList(Label),
    deferredOperands: std.ArrayList(DeferredOperand),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .labels = std.ArrayList(Label).init(allocator),
            .deferredOperands = std.ArrayList(DeferredOperand).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.labels.deinit();
        self.deferredOperands.deinit();
    }

    pub fn find(self: *const Self, name: []const u8) !InstAddr {
        for (self.labels.items) |label| {
            if (std.mem.eql(u8, label.name, name)) {
                return label.address;
            }
        }

        std.debug.print("The label `{s}` does not exist\n", .{name});
        return error.BadJump;
    }
};

fn contains(comptime T: type, slice: []const T, value: T) bool {
    return std.mem.indexOfScalar(T, slice, value) != null;
}

fn pushI64(bm: *Machine, operandStr: []const u8) !void {
    const operand = try std.fmt.parseInt(i64, operandStr, 10);
    try bm.pushInstruction(.{ .Push = @bitCast(Word, operand) });
}

fn pushF64(bm: *Machine, operandStr: []const u8) !void {
    const operand = try std.fmt.parseFloat(f64, operandStr);
    try bm.pushInstruction(.{ .Push = @bitCast(Word, operand) });
}

fn translateSource(source: []const u8, bm: *Machine, ctx: *AssemblerContext) !void {
    var sourcePtr = source;
    bm.programSize = 0;
    while (sourcePtr.len > 0) {
        if (bm.programSize == bm.program.len) {
            return error.ProgramTooLarge;
        }
        var line = string.trim(string.chopByDelim(&sourcePtr, '\n'));
        if (line.len > 0 and line[0] != '#') {
            var instName = string.chopByDelim(&line, ' ');

            if (instName.len > 0 and instName[instName.len - 1] == ':') {
                try ctx.labels.append(.{
                    .name = instName[0 .. instName.len - 1],
                    .address = bm.programSize,
                });

                instName = string.trim(string.chopByDelim(&line, ' '));
            }

            if (instName.len == 0) {
                continue;
            }
            const operandStr = string.trim(string.chopByDelim(&line, '#'));
            if (std.mem.eql(u8, instName, Instruction.name(.Push))) {
                line = string.trimLeft(line);
                pushI64(bm, operandStr) catch {
                    try pushF64(bm, operandStr);
                };
            } else if (std.mem.eql(u8, instName, Instruction.name(.Dup))) {
                line = string.trimLeft(line);
                const operand = try std.fmt.parseInt(i64, operandStr, 10);
                try bm.pushInstruction(.{ .Dup = @bitCast(Word, operand) });
            } else if (std.mem.eql(u8, instName, Instruction.name(.Jump))) {
                line = string.trimLeft(line);
                const operand = std.fmt.parseInt(i64, operandStr, 10) catch null;
                if (operand) |op| {
                    try bm.pushInstruction(.{ .Jump = @bitCast(Word, op) });
                } else {
                    try ctx.deferredOperands.append(.{
                        .label = operandStr,
                        .address = bm.programSize,
                    });
                    try bm.pushInstruction(.{ .Jump = 0 });
                }
            } else if (std.mem.eql(u8, instName, Instruction.name(.PlusI))) {
                try bm.pushInstruction(.PlusI);
            } else if (std.mem.eql(u8, instName, Instruction.name(.PlusF))) {
                try bm.pushInstruction(.PlusF);
            } else if (std.mem.eql(u8, instName, Instruction.name(.Halt))) {
                try bm.pushInstruction(.Halt);
            } else if (std.mem.eql(u8, instName, Instruction.name(.Nop))) {
                try bm.pushInstruction(.Nop);
            } else {
                std.debug.print("ERROR: `{s}` is not a recognized instruction\n", .{instName});
                return error.BadInstruction;
            }
        }
    }

    for (ctx.deferredOperands.items) |jump| {
        switch (bm.program[jump.address]) {
            .Jump => |*target| {
                const label = try ctx.find(jump.label);
                target.* = @intCast(Word, label);
            },
            else => {
                return error.NotAJump;
            },
        }
    }
}

fn usage(executableName: []const u8) void {
    std.debug.print("Usage: {s} <input.basm> <output.bm>\n", .{executableName});
}

pub fn main() !void {
    var gpAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpAllocator.detectLeaks();
    const allocator = gpAllocator.backing_allocator;
    const parsed = args.parseForCurrentProcess(struct {}, allocator, .silent) catch {
        usage("basm");
        return error.InvalidUsage;
    };
    if (parsed.positionals.len < 2) {
        usage(parsed.executable_name.?);
        return error.InvalidUsage;
    }

    const inputFilePath = parsed.positionals[0];
    const outputFilePath = parsed.positionals[1];

    var bm = Machine{};
    var ctx = AssemblerContext.init(allocator);
    defer ctx.deinit();
    var sourceCode = try file.slurp(inputFilePath, allocator);
    defer allocator.free(sourceCode);
    try translateSource(sourceCode, &bm, &ctx);
    try bm.saveProgramToFile(outputFilePath);
}
