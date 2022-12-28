pub fn shift(args: *[][:0]u8) ?[:0]u8 {
    if (args.len > 0) {
        const result = args.*[0];
        args.* = args.*[1..];
        return result;
    }
    return null;
}
