const std = @import("std");
const string = @import("string.zig");
const defs = @import("defs.zig");

const Allocator = std.mem.Allocator;
const Machine = @import("Machine.zig");
const Instruction = @import("instruction.zig").Instruction;
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

fn slurpFile(filePath: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();
    const stat = try file.stat();
    const fileSize = stat.size;
    return try file.readToEndAlloc(allocator, fileSize);
}

pub fn main() !void {
    var gpAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpAllocator.backing_allocator;
    var args = try std.process.argsAlloc(allocator);
    if (args.len < 3) {
        std.debug.print("Usage: {s} <input.basm> <output.bm>\n", .{args[0]});
        std.debug.print("ERROR: expected input and output\n", .{});
        return error.InvalidUsage;
    }

    const inputFilePath = args[1];
    const outputFilePath = args[2];

    var bm = Machine{};
    var sourceCode = try slurpFile(inputFilePath, allocator);
    defer allocator.free(sourceCode);
    bm.programSize = try translateSource(sourceCode, &bm.program);
    try bm.saveProgramToFile(outputFilePath);
    if (gpAllocator.detectLeaks()) {
        return error.LeakedMemory;
    }
}
