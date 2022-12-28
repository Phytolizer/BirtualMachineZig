const std = @import("std");

pub fn shift(args: *[][:0]u8) ?[:0]u8 {
    if (args.len > 0) {
        const result = args.*[0];
        args.* = args.*[1..];
        return result;
    }
    return null;
}

pub fn genUsage(comptime usage: anytype) fn (anytype, []const u8) void {
    return struct {
        fn printUsage(writer: anytype, program: []const u8) void {
            writer.print(
                "Usage: {s} " ++ usage ++ "\n",
                .{program},
            ) catch unreachable;
        }
    }.printUsage;
}

pub fn showErr(
    comptime usage: fn (anytype, []const u8) void,
    program: []const u8,
    comptime fmt: []const u8,
    args: anytype,
) error{Usage} {
    usage(std.io.getStdErr().writer(), program);
    std.debug.print("ERROR: " ++ fmt ++ "\n", args);
    return error.Usage;
}
