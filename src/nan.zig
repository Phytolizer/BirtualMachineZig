const std = @import("std");

const isNan = std.math.isNan;

const exp_mask = @as(u64, ((1 << 11) - 1) << 52);
const fraction_mask = @as(u64, (1 << 52) - 1);
const sign_mask = @as(u64, 1 << 63);
const type_mask = @as(u64, ((1 << 4) - 1) << 48);
const value_mask = @as(u64, (1 << 48) - 1);

fn mkType(ty: u3) u64 {
    return 0b1000 | @as(u64, ty);
}

const type_int = @as(u64, mkType(0));
const type_pointer = @as(u64, mkType(1));

fn getType(x: f64) u64 {
    const y = @bitCast(u64, x);
    return (y & type_mask) >> 48;
}

fn getValue(x: f64) u64 {
    const y = @bitCast(u64, x);
    return y & value_mask;
}

fn setType(x: f64, ty: u64) f64 {
    var y = @bitCast(u64, x);
    y = (y & ~type_mask) | (((type_mask >> 48) & ty) << 48);
    return @bitCast(f64, y);
}

fn setValue(x: f64, value: u64) f64 {
    var y = @bitCast(u64, x);
    y = (y & ~value_mask) | (value & value_mask);
    return @bitCast(f64, y);
}

fn mkInf() f64 {
    return @bitCast(f64, exp_mask);
}

fn isDouble(x: f64) bool {
    return !isNan(x);
}

fn isInteger(x: f64) bool {
    return isNan(x) and getType(x) == type_int;
}

fn isPointer(x: f64) bool {
    return isNan(x) and getType(x) == type_pointer;
}

fn asDouble(x: f64) f64 {
    return x;
}

fn asInteger(x: f64) u64 {
    return getValue(x);
}

fn asPointer(x: f64) ?*anyopaque {
    return @intToPtr(?*anyopaque, getValue(x));
}

fn boxDouble(x: f64) f64 {
    return x;
}

fn boxInteger(x: u64) f64 {
    return setValue(setType(mkInf(), type_int), x);
}

fn boxPointer(x: anytype) f64 {
    switch (@typeInfo(@TypeOf(x))) {
        .Pointer => {},
        .Optional => |opt| {
            _ = @typeInfo(opt.child).Pointer;
        },
        else => @compileError("can't box non-pointer")
    }
    return setValue(setType(mkInf(), type_pointer), @ptrToInt(x));
}

pub fn main() !void {
    var x: f64 = 34894.34923;

    std.debug.assert(boxDouble(std.math.pi) == asDouble(boxDouble(std.math.pi)));
    std.debug.assert(12345678 == asInteger(boxInteger(12345678)));
    std.debug.assert(&x == @ptrCast(*f64, asPointer(boxPointer(&x))));
}
