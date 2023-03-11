const std = @import("std");
const Allocator = std.mem.Allocator;
const Array = @This();
const Value = @import("value.zig").Value;
const assert = std.debug.assert;
const IntType = @import("types.zig").IntType;

rc: i32,
eles: std.ArrayListUnmanaged(Value),

pub fn initCapacity(cap: usize, alloc: Allocator) Allocator.Error!*Array {
    var ary = try alloc.create(alloc);
    errdefer alloc.destroy(ary);

    ary.rc = 1;
    ary.eles = try std.ArrayListUnmanaged(Value).initCapacity(cap);
    return ary;
}

pub fn increment(this: *Array) void {
    this.rc += 1;
}

pub fn decrement(this: *Array, alloc: Allocator) void {
    assert(this.rc != 0);
    this.rc -= 1;
    if (this.rc == 0) {
        this.deinit(alloc);
    }
}

pub fn deinit(this: *Array, alloc: Allocator) void {
    assert(this.rc == 0);
    for (this.eles.items) |value| {
        value.deinit(alloc);
    }
    this.eles.deinit(alloc);
    alloc.destroy(this);
}

pub fn equals(this: *const Array, other: *const Array) bool {
    if (this == other) {
        return true;
    }

    if (this.eles.items.len != other.eles.items.len) {
        return false;
    }

    for (this.eles.items) |value, index| {
        if (!value.equals(other.eles.items[index])) {
            return false;
        }
    }

    return true;
}

pub const ParseIntError = error{NotAnArrayOfInts};
pub fn parseInt(this: *const Array) ParseIntError!IntType {
    const minus = comptime Value.fromInt('-');
    var int: IntType = 0;
    var sign: IntType = 1;
    var idx: usize = 0;

    if (this.eles.items[idx].equals(minus)) {
        sign = -1;
        idx += 1;
    }

    while (idx < this.eles.items.len) : (idx += 1) {
        switch (this.eles.items[idx].classify()) {
            .int => |i| int = (int * 10) + (i - '0'),
            else => return error.NotAnArrayOfInts,
        }
    }

    return int * sign;
}

pub fn format(
    this: *const Array,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    _ = fmt;
    _ = options;
    try writer.writeAll("[");

    for (this.eles.items) |value, idx| {
        if (idx != 0) {
            try writer.writeAll(", ");
        }

        try writer.print("{}", value);
    }

    try writer.writeAll("]");
}

pub fn print(this: *const Array, writer: anytype) Value.PrintError!void {
    for (this.eles.items) |value| {
        try value.print(writer);

        if (value.classify() == .ary) {
            try writer.writeAll("\n");
        }
    }
}

// pub fn toString(this: *const Array, alloc: Allocator) Allocator.Error!Value {

// }

// array *to_string(VALUE v) {
//     if (!isint(v)) return ARY(clone(v));

//     char buf[100]; // large enough
//     snprintf(buf, sizeof(buf), "%lld", INT(v));

//     array *a = aalloc(strlen(buf));
//     for (int i = 0; buf[i]; ++i)
//         a->items[a->len++] = i2v(buf[i]);

//     return a;
// }
