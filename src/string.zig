const std = @import("std");

pub fn trimLeft(s: []const u8) []const u8 {
    var i: usize = 0;
    while (i < s.len and std.ascii.isSpace(s[i])) {
        i += 1;
    }
    return s[i..];
}

pub fn trimRight(s: []const u8) []const u8 {
    var i: usize = s.len;
    while (i > 0 and std.ascii.isSpace(s[i - 1])) {
        i -= 1;
    }
    return s[0..i];
}

pub fn trim(s: []const u8) []const u8 {
    return trimLeft(trimRight(s));
}

pub fn chopByDelim(s: *[]const u8, delim: u8) []const u8 {
    const end = std.mem.indexOfScalar(u8, s.*, delim);
    const result = s.*[0..(end orelse s.len)];
    s.* = if (end) |e|
        s.*[e + 1 ..]
    else
        s.*[s.len..];
    return result;
}
