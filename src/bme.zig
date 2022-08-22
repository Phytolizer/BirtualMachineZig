const std = @import("std");
const libbm = @import("bm");
const args = @import("args");

const Machine = libbm.Machine;

fn usage(comptime Writer: type, writer: Writer, executableName: []const u8) !void {
    try writer.print("Usage: {s} <-i input.bm> [-l limit] [-d]\n", .{executableName});
}

fn ignoreLine(reader: anytype) !bool {
    var buf: [1024]u8 = undefined;
    var line = try reader.readUntilDelimiterOrEof(&buf, '\n');
    return line != null;
}

pub fn main() !void {
    var gpAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpAllocator.detectLeaks();
    const allocator = gpAllocator.backing_allocator;

    const stderr = std.io.getStdErr().writer();

    const parsed = args.parseForCurrentProcess(struct {
        input: ?[]const u8 = null,
        limit: ?usize = null,
        help: bool = false,
        debug: bool = false,

        pub const shorthands = .{
            .i = "input",
            .l = "limit",
            .h = "help",
            .d = "debug",
        };
    }, allocator, .silent) catch |e| {
        try usage(@TypeOf(stderr), stderr, "bme");
        return e;
    };
    if (parsed.options.input == null) {
        try usage(@TypeOf(stderr), stderr, parsed.executable_name.?);
        std.debug.print("ERROR: expected input\n", .{});
        return error.InvalidUsage;
    }
    const stdout = std.io.getStdOut().writer();
    if (parsed.options.help) {
        try usage(@TypeOf(stdout), stdout, parsed.executable_name.?);
        return;
    }

    const inputFilePath = parsed.options.input.?;

    if (parsed.options.debug) {
        var bm = try Machine.initFromFile(inputFilePath);
        const limit = parsed.options.limit;
        var i: usize = 0;
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        while ((limit == null or i < limit.?) and !bm.halt) : (i += 1) {
            try bm.dumpStack(@TypeOf(stdout), stdout);
            if (!try ignoreLine(std.io.getStdIn().reader())) {
                break;
            }
            try bm.executeInstruction();
        }
    } else {
        var bm = try Machine.initFromFile(inputFilePath);
        bm.executeProgram(parsed.options.limit) catch |e| {
            try bm.dumpStack(@TypeOf(stderr), stderr);
            std.debug.print("error at {d}\n", .{bm.ip});
            return e;
        };
    }
}
