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

const UnresolvedJump = struct {
    address: usize,
    label: []const u8,
};

const Label = struct {
    name: []const u8,
    address: usize,
};

const LabelTable = struct {
    labels: std.ArrayList(Label),
    unresolvedJumps: std.ArrayList(UnresolvedJump),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .labels = std.ArrayList(Label).init(allocator),
            .unresolvedJumps = std.ArrayList(UnresolvedJump).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.labels.deinit();
        self.unresolvedJumps.deinit();
    }

    pub fn find(self: *const Self, name: []const u8) !usize {
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

fn translateSource(source: []const u8, bm: *Machine, lt: *LabelTable) !void {
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
                try lt.labels.append(.{
                    .name = instName[0 .. instName.len - 1],
                    .address = bm.programSize,
                });

                instName = string.trim(string.chopByDelim(&line, ' '));
            }

            if (instName.len == 0) {
                continue;
            }
            const operandStr = string.trim(string.chopByDelim(&line, '#'));
            if (std.mem.eql(u8, instName, "push")) {
                line = string.trimLeft(line);
                const operand = try std.fmt.parseInt(Word, operandStr, 10);
                try bm.pushInstruction(.{ .Push = operand });
            } else if (std.mem.eql(u8, instName, "dup")) {
                line = string.trimLeft(line);
                const operand = try std.fmt.parseInt(Word, operandStr, 10);
                try bm.pushInstruction(.{ .Dup = operand });
            } else if (std.mem.eql(u8, instName, "jmp")) {
                line = string.trimLeft(line);
                const operand = std.fmt.parseInt(Word, operandStr, 10) catch null;
                if (operand) |op| {
                    try bm.pushInstruction(.{ .Jump = op });
                } else {
                    try lt.unresolvedJumps.append(.{
                        .label = operandStr,
                        .address = bm.programSize,
                    });
                    try bm.pushInstruction(.{ .Jump = 0 });
                }
            } else if (std.mem.eql(u8, instName, "plus")) {
                try bm.pushInstruction(.Plus);
            } else if (std.mem.eql(u8, instName, "halt")) {
                try bm.pushInstruction(.Halt);
            } else if (std.mem.eql(u8, instName, "nop")) {
                try bm.pushInstruction(.Nop);
            } else {
                std.debug.print("ERROR: `{s}` is not a recognized instruction\n", .{instName});
                return error.BadInstruction;
            }
        }
    }

    for (lt.unresolvedJumps.items) |jump| {
        switch (bm.program[jump.address]) {
            .Jump => |*target| {
                const label = try lt.find(jump.label);
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
    var lt = LabelTable.init(allocator);
    defer lt.deinit();
    var sourceCode = try file.slurp(inputFilePath, allocator);
    defer allocator.free(sourceCode);
    try translateSource(sourceCode, &bm, &lt);
    try bm.saveProgramToFile(outputFilePath);
}
