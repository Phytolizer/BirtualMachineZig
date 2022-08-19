const std = @import("std");
const libbm = @import("bm");
const args = @import("args");
const defs = libbm.defs;
const string = libbm.string;
const file = libbm.file;

const Machine = libbm.Machine;
const Instruction = libbm.instruction.Instruction;
const Word = defs.Word;

const executionLimit = defs.executionLimit;

fn translateLine(lineIn: []const u8) !Instruction {
    var line = lineIn;
    const instName = string.chopByDelim(&line, ' ');

    if (std.mem.eql(u8, instName, "push")) {
        line = string.trimLeft(line);
        const operand = try std.fmt.parseInt(Word, string.trimRight(line), 10);
        return Instruction{ .Push = operand };
    }
    if (std.mem.eql(u8, instName, "dup")) {
        line = string.trimLeft(line);
        const operand = try std.fmt.parseInt(Word, string.trimRight(line), 10);
        return Instruction{ .Dup = operand };
    }
    if (std.mem.eql(u8, instName, "jmp")) {
        line = string.trimLeft(line);
        const operand = try std.fmt.parseInt(Word, string.trimRight(line), 10);
        return Instruction{ .Jump = operand };
    }
    if (std.mem.eql(u8, instName, "plus")) {
        return Instruction.Plus;
    }
    if (std.mem.eql(u8, instName, "halt")) {
        return Instruction.Halt;
    }
    std.debug.print("ERROR: `{s}` is not a recognized instruction\n", .{instName});
    return error.BadInstruction;
}

fn translateSource(source: []const u8, program: []Instruction) !usize {
    _ = program;
    var sourcePtr = source;
    var programSize: usize = 0;
    while (sourcePtr.len > 0) {
        const line = string.trim(string.chopByDelim(&sourcePtr, '\n'));
        if (line.len > 0) {
            program[programSize] = try translateLine(line);
            programSize += 1;
        }
    }
    return programSize;
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
    var sourceCode = try file.slurp(inputFilePath, allocator);
    defer allocator.free(sourceCode);
    bm.programSize = try translateSource(sourceCode, &bm.program);
    try bm.saveProgramToFile(outputFilePath);
}
