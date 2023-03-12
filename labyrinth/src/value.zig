const std = @import("std");
const Allocator = std.mem.Allocator;
const Array = @import("Array.zig");
const assert = std.debug.assert;
const IntType = @import("types.zig").IntType;

pub const ValueType = union(enum) {
    int: IntType,
    ary: *Array,
};

pub const Value = struct {
    const DataType = i64;

    _data: DataType,

    pub fn from(val: anytype) Value {
        return switch (@TypeOf(val)) {
            IntType, comptime_int => .{ ._data = (@intCast(DataType, val) << 1) | 1 },
            bool => Value.from(@as(IntType, if (val) 1 else 0)),
            *Array => .{ ._data = @intCast(DataType, @ptrToInt(val)) },
            else => unreachable,
        };
    }

    pub inline fn classify(this: Value) ValueType {
        return if (this._data & 1 == 1) .{
            .int = @intCast(IntType, this._data >> 1),
        } else .{
            .ary = @intToPtr(*Array, @intCast(usize, this._data)),
        };
    }

    pub fn clone(this: Value) Value {
        switch (this.classify()) {
            .int => {},
            .ary => |ary| ary.increment(),
        }

        return this;
    }

    pub fn deinit(this: Value, alloc: Allocator) void {
        switch (this.classify()) {
            .int => {},
            .ary => |ary| ary.decrement(alloc),
        }
    }

    pub fn isTruthy(this: Value) bool {
        return switch (this.classify()) {
            .int => |int| int != 0,
            .ary => |ary| switch (ary.eles.items.len) {
                0 => false,
                1 => ary.eles.items[0].isTruthy(), // `[0]` is falsey.
                else => true,
            },
        };
    }

    pub fn len(this: Value) usize {
        return switch (this.classify()) {
            .int => 1,
            .ary => |ary| ary.eles.items.len,
        };
    }

    pub fn equals(this: Value, other: Value) bool {
        if (this._data == other._data)
            return true;

        return switch (this.classify()) {
            .int => false,
            .ary => |lhs| switch (other.classify()) {
                .int => false,
                .ary => |rhs| lhs.equals(rhs),
            },
        };
    }

    pub fn format(
        this: Value,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) std.os.WriteError!void {
        return switch (this.classify()) {
            .int => |int| writer.print("{d}", .{int}),
            .ary => |ary| writer.print("{}", .{ary}),
        };
    }

    pub const PrintError = error{IntOutOfBounds} || std.os.WriteError;
    pub fn print(this: Value, writer: anytype) PrintError!void {
        return switch (this.classify()) {
            .int => |int| writer.writeByte(std.math.cast(u8, int) orelse return error.IntOutOfBounds),
            .ary => |ary| ary.print(writer),
        };
    }

    pub fn toInt(this: Value) Array.ParseIntError!IntType {
        return switch (this.classify()) {
            .int => |int| int,
            .ary => |ary| ary.parseInt(),
        };
    }

    pub fn toString(this: Value, alloc: Allocator) Allocator.Error!*Array {
        switch (this.classify()) {
            .int => |int| {
                var buf: [255]u8 = undefined; // 255 is plenty.
                const bytes = std.fmt.bufPrint(&buf, "{d}", .{int}) catch unreachable;
                var ary = try Array.initCapacity(alloc, bytes.len);

                for (bytes) |byte|
                    ary.push(alloc, Value.from(@intCast(IntType, byte))) catch unreachable;

                return ary;
            },
            .ary => |ary| {
                ary.increment();
                return ary;
            },
        }
    }

    pub const MathError = error{ArrayLengthMismatch} || Allocator.Error;

    fn mapIt(
        this: Value,
        alloc: Allocator,
        rhs: Value,
        comptime func: fn (IntType, IntType) IntType,
    ) MathError!Value {
        switch (this.classify()) {
            .int => |l| switch (rhs.classify()) {
                .int => |r| return Value.from(func(l, r)),
                .ary => |a| {
                    var ary = try Array.initCapacity(alloc, a.len());
                    for (a.eles.items) |value|
                        ary.push(alloc, try this.mapIt(alloc, value, func)) catch unreachable;
                    return Value.from(ary);
                },
            },
            .ary => |a| switch (rhs.classify()) {
                .int => {
                    var ary = try Array.initCapacity(alloc, a.len());
                    for (a.eles.items) |value|
                        ary.push(alloc, try value.mapIt(alloc, rhs, func)) catch unreachable;
                    return Value.from(ary);
                },
                .ary => |r| {
                    if (a.len() != r.len()) return error.ArrayLengthMismatch;
                    var ary = try Array.initCapacity(alloc, a.len());

                    for (a.eles.items) |lvalue, i|
                        ary.push(alloc, try lvalue.mapIt(alloc, r.eles.items[i], func)) catch unreachable;
                    return Value.from(ary);
                },
            },
        }
    }

    pub fn add(this: Value, alloc: Allocator, rhs: Value) MathError!Value {
        return this.mapIt(alloc, rhs, struct {
            fn it(a: IntType, b: IntType) IntType {
                return a + b;
            }
        }.it);
    }

    pub fn sub(this: Value, alloc: Allocator, rhs: Value) MathError!Value {
        return this.mapIt(alloc, rhs, struct {
            fn it(a: IntType, b: IntType) IntType {
                return a - b;
            }
        }.it);
    }

    pub fn mul(this: Value, alloc: Allocator, rhs: Value) MathError!Value {
        return this.mapIt(alloc, rhs, struct {
            fn it(a: IntType, b: IntType) IntType {
                return a * b;
            }
        }.it);
    }

    pub fn div(this: Value, alloc: Allocator, rhs: Value) MathError!Value {
        return this.mapIt(alloc, rhs, struct {
            fn it(a: IntType, b: IntType) IntType {
                return @divTrunc(a, b);
            }
        }.it);
    }

    pub fn mod(this: Value, alloc: Allocator, rhs: Value) MathError!Value {
        return this.mapIt(alloc, rhs, struct {
            fn it(a: IntType, b: IntType) IntType {
                return @mod(a, b);
            }
        }.it);
    }

    pub fn cmp(this: Value, rhs: Value) IntType {
        _ = this;
        _ = rhs;
        // switch (this.classify()) {
        //     .int => |l| switch (rhs.classify()) {
        //         .int => |r| return Value.from(l - r),
        //         .ary => |a| {
        //             var ary = try Array.initCapacity(alloc, a.len());
        //             for (a.eles.items) |value|
        //                 ary.push(alloc, try this.mapIt(alloc, value, func)) catch unreachable;
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

    pub fn chr(this: Value, alloc: Allocator) Allocator.Error!Value {
        switch (this.classify()) {
            .int => {
                var ary = try Array.initCapacity(alloc, 1);
                ary.push(alloc, this) catch unreachable;
                return Value.from(ary);
            },
            .ary => |ary| {
                ary.increment();
                return this;
            },
        }
    }

    pub const OrdError = error{EmptyString};
    pub fn ord(this: Value) OrdError!Value {
        return switch (this.classify()) {
            .int => this,
            .ary => |ary| if (ary.len() == 0) error.EmptyString else ary.eles.items[0].ord(),
        };
    }
};
