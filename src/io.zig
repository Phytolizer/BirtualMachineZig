const std = @import("std");

pub fn makeOutFn(
    comptime writer: fn () std.fs.File.Writer,
    comptime transform: fn (comptime fmt: []const u8) []const u8,
) fn (comptime fmt: []const u8, args: anytype) void {
    return struct {
        fn f(comptime fmt: []const u8, args: anytype) void {
            writer().print(transform(fmt), args) catch unreachable;
        }
    }.f;
}

pub fn getStdOut() std.fs.File.Writer {
    return std.io.getStdOut().writer();
}

pub fn getStdErr() std.fs.File.Writer {
    return std.io.getStdErr().writer();
}

fn identity(comptime fmt: []const u8) []const u8 {
    return fmt;
}

fn newline(comptime fmt: []const u8) []const u8 {
    return fmt ++ "\n";
}

pub const out = makeOutFn(getStdOut, identity);
pub const err = makeOutFn(getStdErr, identity);
pub const outLine = makeOutFn(getStdOut, newline);
pub const errLine = makeOutFn(getStdErr, newline);

const error_newline = struct {
    fn error_newline(comptime fmt: []const u8) []const u8 {
        return "ERROR: " ++ fmt ++ "\n";
    }
}.error_newline;
pub const showErr = makeOutFn(getStdErr, error_newline);
