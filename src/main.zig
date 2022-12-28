const std = @import("std");
const bm = @import("bm.zig");

var machine = bm.Bm{};

pub fn main() void {
    run() catch std.process.exit(1);
}

fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const a = gpa.allocator();

    const args = try std.process.argsAlloc(a);
    defer std.process.argsFree(a, args);

    if (args.len < 3) {
        std.debug.print("Usage: {s} <input.basm> <output.bm>\n", .{args[0]});
        std.debug.print("ERROR: expected input and output\n", .{});
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
    machine.program_size = try bm.translateAsm(source_code, &machine.program);
    const stdout = std.io.getStdOut().writer();
    var i: usize = 0;
    while (i < bm.execution_limit and !machine.halt) : (i += 1) {
        machine.executeInst() catch |e| {
            std.debug.print("Trap activated: {s}\n", .{bm.trapName(e)});
            machine.dumpStack(std.io.getStdErr().writer()) catch unreachable;
            std.process.exit(1);
        };
    }
    try machine.dumpStack(stdout);

    try machine.saveProgramToFile(out_path);
}
