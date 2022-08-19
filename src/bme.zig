const std = @import("std");
const libbm = @import("bm");
const args = @import("args");

const Machine = libbm.Machine;

fn usage(comptime Writer: type, writer: Writer, executableName: []const u8) !void {
    try writer.print("Usage: {s} <-i input.bm> [-l limit]\n", .{executableName});
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

        pub const shorthands = .{
            .i = "input",
            .l = "limit",
            .h = "help",
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

    var bm = try Machine.initFromFile(inputFilePath);
    bm.executeProgram(parsed.options.limit) catch |e| {
        try bm.dumpStack(@TypeOf(stderr), stderr);
        return e;
    };
    try bm.dumpStack(@TypeOf(stdout), stdout);
}
