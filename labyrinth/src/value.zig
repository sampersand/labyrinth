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
            *Array => .{ ._data = @intCast(DataType, @ptrToInt(val)) },
            else => unreachable,
        };
    }

    pub fn isInt(this: Value) bool {
        return this._data & 1 == 1;
    }

    pub fn asInt(this: Value) IntType {
        assert(this.isInt());
        return @intCast(IntType, this._data >> 1);
    }

    pub fn asArray(this: Value) *Array {
        assert(!this.isInt());
        return @intToPtr(*Array, @intCast(usize, this._data));
    }

    pub inline fn classify(this: Value) ValueType {
        return if (this.isInt()) .{ .int = this.asInt() } else .{ .ary = this.asArray() };
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
            .ary => |ary| ary.eles.items.len != 0,
        };
    }

    pub fn len(this: Value) usize {
        return switch (this.classify()) {
            .int => 1,
            .ary => |ary| ary.eles.len,
        };
    }

    pub fn equals(this: Value, other: Value) bool {
        if (this._data == other._data) {
            return true;
        }

        if (this.isInt() or other.isInt()) {
            return false;
        }

        return this.asArray().equals(other.asArray());
    }

    pub fn format(
        this: Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) std.os.WriteError!void {
        _ = fmt;
        _ = options;

        switch (this.classify()) {
            .int => |int| try writer.print("{d}", .{int}),
            .ary => |ary| try writer.print("{}", .{ary}),
        }
    }

    pub const PrintError = error{IntOutOfBounds} || std.os.WriteError;
    pub fn print(this: Value, writer: anytype) PrintError!void {
        switch (this.classify()) {
            .int => |int| {
                const byte = std.math.cast(u8, int) orelse return error.IntOutOfBounds;
                try writer.writeByte(byte);
            },
            .ary => |ary| try ary.print(writer),
        }
    }

    pub fn toInt(this: Value) !IntType {
        return switch (this.classify()) {
            .int => |int| int,
            .ary => |ary| ary.parseInt(),
        };
    }

    pub fn toString(this: Value) !*Array {
        return switch (this.classify()) {
            .int => |int| {
                _ = int;
                // allocPrint
                @panic("todo");
            },
            .ary => |ary| ary.increment(),
        };
    }
};
