const std = @import("std");
const Allocator = std.mem.Allocator;
const Array = @import("Array.zig");
const utils = @import("utils.zig");
const assert = std.debug.assert;
const int_type = @import("types.zig");
const IntType = int_type.IntType;

const Value = @This();

/// A helper type used for the reutrn value of `classify`.
pub const ValueType = union(enum) {
    int: IntType,
    ary: *Array,
};

pub const DataType = i64;
_data: DataType,

/// Creates a new value from `val`.
pub fn from(ty: anytype) Value {
    return switch (@TypeOf(ty)) {
        IntType, comptime_int => .{ ._data = (@intCast(DataType, ty) << 1) | 1 },
        bool => Value.from(@as(IntType, if (ty) 1 else 0)),
        *Array => .{ ._data = @intCast(DataType, @ptrToInt(ty)) },
        else => @compileError("Value.from error: " ++ @typeName(@TypeOf(ty))),
    };
}

/// Returns an enum for pattern matching for `value`.
pub inline fn classify(value: Value) ValueType {
    return if (value._data & 1 == 1) .{
        .int = @intCast(IntType, value._data >> 1),
    } else .{
        .ary = @intToPtr(*Array, @intCast(usize, @intCast(u64, value._data))),
    };
}

/// Duplicates `value`.
pub fn clone(value: Value) Value {
    switch (value.classify()) {
        .int => {},
        .ary => |ary| ary.increment(),
    }

    return value;
}

/// Deinitializes `value`.
pub fn deinit(value: Value, alloc: Allocator) void {
    switch (value.classify()) {
        .int => {},
        .ary => |ary| ary.decrement(alloc),
    }
}

/// Checks to see if `value` is truthy.
///
/// Only zero and empty arrays are falsey.
pub fn isTruthy(value: Value) bool {
    return switch (value.classify()) {
        .int => |int| int != 0,
        .ary => |ary| !ary.isEmpty(),
    };
}

/// Checks to see if `value` is equal to `other`.
pub fn equals(value: Value, other: Value) bool {
    if (value._data == other._data)
        return true;

    return switch (value.classify()) {
        .int => false,
        .ary => |lhs| switch (other.classify()) {
            .int => false,
            .ary => |rhs| lhs.equals(rhs),
        },
    };
}

/// Prints `value`.
///
/// If `fmt` is `d`, it'll print out as an int (or array of ints). If it's `s`,
/// it'll print out as a string. If it's empty, it'll do a debug representation. anything else is an
/// error.
pub fn format(
    value: Value,
    comptime fmt: []const u8,
    opts: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    return switch (value.classify()) {
        .ary => |ary| ary.format(fmt, opts, writer),
        .int => |int| {
            switch (comptime utils.FmtEnum.mustFrom(fmt)) {
                .d, .any => try writer.print("{d}", .{int}),
                .s => {
                    var buf: [std.math.maxInt(u3)]u8 = undefined;
                    const len = std.unicode.utf8Encode(
                        std.math.cast(u21, int) orelse return error.Unexpected,
                        &buf,
                    ) catch return error.Unexpected;
                    try writer.writeAll(buf[0..len]);
                },
            }
        },
    };
}

/// Converts `value` to an integer.
pub fn toInt(value: Value) Array.ParseIntError!IntType {
    return switch (value.classify()) {
        .int => |int| int,
        .ary => |ary| ary.parseInt(),
    };
}

/// Converts `value` to an array.
pub fn toArray(value: Value, alloc: Allocator) Allocator.Error!*Array {
    switch (value.classify()) {
        .int => |int| return int_type.toArray(int, alloc),
        .ary => |ary| {
            ary.increment();
            return ary;
        },
    }
}

pub const MathError = error{ArrayLengthMismatch} || Allocator.Error;

fn mapIt(
    value: Value,
    alloc: Allocator,
    rhs: Value,
    comptime func: fn (IntType, IntType) IntType,
) MathError!Value {
    switch (value.classify()) {
        .int => |l| switch (rhs.classify()) {
            .int => |r| return Value.from(func(l, r)),
            .ary => |a| {
                var ary = Array.empty;
                var iter = a.iter();
                while (iter.next()) |item|
                    ary = try ary.prependNoIncrement(alloc, try value.mapIt(alloc, item, func));
                return Value.from(ary);
            },
        },
        .ary => |a| switch (rhs.classify()) {
            .int => {
                var ary = Array.empty;
                var iter = a.iter();
                while (iter.next()) |item|
                    ary = try ary.prependNoIncrement(alloc, try item.mapIt(alloc, rhs, func));
                return Value.from(ary);
            },
            .ary => |r| {
                var ary = Array.empty;
                var liter = a.iter();
                var riter = r.iter();
                while (liter.next()) |left| {
                    const right = riter.next() orelse return error.ArrayLengthMismatch;
                    ary = try ary.prependNoIncrement(alloc, try left.mapIt(alloc, right, func));
                }

                return if (riter.next() == null) Value.from(ary) else error.ArrayLengthMismatch;
            },
        },
    }
}

pub fn add(value: Value, alloc: Allocator, rhs: Value) MathError!Value {
    return value.mapIt(alloc, rhs, struct {
        fn it(a: IntType, b: IntType) IntType {
            return a + b;
        }
    }.it);
}

pub fn sub(value: Value, alloc: Allocator, rhs: Value) MathError!Value {
    return value.mapIt(alloc, rhs, struct {
        fn it(a: IntType, b: IntType) IntType {
            return a - b;
        }
    }.it);
}

pub fn mul(value: Value, alloc: Allocator, rhs: Value) MathError!Value {
    return value.mapIt(alloc, rhs, struct {
        fn it(a: IntType, b: IntType) IntType {
            return a * b;
        }
    }.it);
}

pub fn div(value: Value, alloc: Allocator, rhs: Value) MathError!Value {
    return value.mapIt(alloc, rhs, struct {
        fn it(a: IntType, b: IntType) IntType {
            return @divTrunc(a, b);
        }
    }.it);
}

pub fn mod(value: Value, alloc: Allocator, rhs: Value) MathError!Value {
    return value.mapIt(alloc, rhs, struct {
        fn it(a: IntType, b: IntType) IntType {
            return @mod(a, b);
        }
    }.it);
}

pub fn cmp(value: Value, rhs: Value) IntType {
    _ = value;
    _ = rhs;
    // switch (value.classify()) {
    //     .int => |l| switch (rhs.classify()) {
    //         .int => |r| return Value.from(l - r),
    //         .ary => |a| {
    //             var ary = try Array.initCapacity(alloc, a.len());
    //             for (a.eles.items) |value|
    //                 ary.push(alloc, try value.mapIt(alloc, value, func)) catch unreachable;
    //             return Value.from(ary);
    //         },
    //     },
    //     .ary => |a| switch (rhs.classify()) {
    //         .int => {
    //             var ary = try Array.initCapacity(alloc, a.len());
    //             for (a.eles.items) |value|
    //                 ary.push(alloc, try value.mapIt(alloc, rhs, func)) catch unreachable;
    //             return Value.from(ary);
    //         },
    //         .ary => |r| {
    //             if (a.len() != r.len()) return error.ArrayLengthMismatch;
    //             var ary = try Array.initCapacity(alloc, a.len());

    //             for (a.eles.items) |lvalue, i|
    //                 ary.push(alloc, try lvalue.mapIt(alloc, r.eles.items[i], func)) catch unreachable;
    //             return Value.from(ary);
    //         },
    //     },
    // }

    @panic("todo");
}

pub fn chr(value: Value, alloc: Allocator) Allocator.Error!Value {
    switch (value.classify()) {
        .int => return Value.from(try Array.init(alloc, value)),
        .ary => |ary| {
            ary.increment();
            return value;
        },
    }
}

pub const OrdError = error{EmptyString};
pub fn ord(value: Value) OrdError!Value {
    return switch (value.classify()) {
        .int => value,
        .ary => |ary| b: {
            var iter = ary.iter();
            break :b if (iter.next()) |ele| ele.ord() else error.EmptyString;
        },
    };
}
