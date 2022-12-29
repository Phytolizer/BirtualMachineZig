const std = @import("std");

pub fn charBeforeEnd(slice: []const u8, ofs: usize) u8 {
    return slice[slice.len - ofs];
}

pub fn beforeEnd(slice: []const u8, ofs: usize) []const u8 {
    return slice[0 .. slice.len - ofs];
}
