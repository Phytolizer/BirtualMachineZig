const std = @import("std");

const Allocator = std.mem.Allocator;

pub fn slurp(filePath: []const u8, allocator: Allocator) ![]u8 {
    var file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();
    const stat = try file.stat();
    const fileSize = stat.size;
    return try file.readToEndAlloc(allocator, fileSize);
}
