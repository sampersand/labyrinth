const std = @import("std");
const Allocator = std.mem.Allocator;
const Array = @This();
const Value = @import("value.zig").Value;
const assert = std.debug.assert;
const IntType = @import("types.zig").IntType;

refcount: u32,
eles: std.ArrayListUnmanaged(Value),

pub fn init(alloc: Allocator) Allocator.Error!*Array {
    return initCapacity(alloc, 0);
}

pub fn initCapacity(alloc: Allocator, cap: usize) Allocator.Error!*Array {
    var ary = try alloc.create(Array);
    errdefer alloc.destroy(ary);

    ary.refcount = 1;
    ary.eles = try std.ArrayListUnmanaged(Value).initCapacity(alloc, cap);
    return ary;
}

pub fn increment(this: *Array) void {
    this.refcount += 1;
}

pub fn decrement(this: *Array, alloc: Allocator) void {
    assert(this.refcount != 0);
    this.refcount -= 1;
    if (this.refcount == 0) this.deinit(alloc);
}

pub fn deinit(this: *Array, alloc: Allocator) void {
    assert(this.refcount == 0);
    this.deinitNoCheck(alloc);
}

pub fn deinitNoCheck(this: *Array, alloc: Allocator) void {
    for (this.eles.items) |value| value.deinit(alloc);
    this.eles.deinit(alloc);
    alloc.destroy(this);
}

pub fn push(this: *Array, alloc: Allocator, value: Value) Allocator.Error!void {
    try this.eles.append(alloc, value);
}

pub fn pop(this: *Array) ?Value {
    return this.eles.popOrNull();
}

pub fn len(this: *const Array) usize {
    return this.eles.items.len;
}

pub fn equals(this: *const Array, other: *const Array) bool {
    if (this == other) return true;
    if (this.len() != other.len()) return false;

    for (this.eles.items) |value, index| {
        if (!value.equals(other.eles.items[index])) {
            return false;
        }
    }

    return true;
}

pub const ParseIntError = error{NotAnArrayOfInts};
pub fn parseInt(this: *const Array) ParseIntError!IntType {
    if (this.len() == 0) return 0;

    const minus = comptime Value.from('-');
    var int: IntType = 0;
    var sign: IntType = 1;
    var idx: usize = 0;

    if (this.eles.items[idx].equals(minus)) {
        sign = -1;
        idx += 1;
    }

    while (idx < this.len()) : (idx += 1) {
        switch (this.eles.items[idx].classify()) {
            .int => |i| {
                if (i < '0' or '9' < i) break;
                int = (int * 10) + (i - '0');
            },
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

const testAlloc = std.testing.allocator;
test "refcount defaults to 1, len starts as 0" {
    var ary = try Array.init(testAlloc);
    defer ary.deinitNoCheck(testAlloc);

    try std.testing.expectEqual(@as(u32, 1), ary.refcount);
    try std.testing.expectEqual(@as(usize, 0), ary.len());
}

test "refcount works as expected" {
    var ary = try Array.init(testAlloc);

    try std.testing.expectEqual(@as(u32, 1), ary.refcount);
    ary.increment();
    try std.testing.expectEqual(@as(u32, 2), ary.refcount);
    ary.increment();
    try std.testing.expectEqual(@as(u32, 3), ary.refcount);

    ary.decrement(undefined);
    try std.testing.expectEqual(@as(u32, 2), ary.refcount);
    ary.decrement(undefined);
    try std.testing.expectEqual(@as(u32, 1), ary.refcount);
    ary.decrement(testAlloc);
}

test "deinit also deinits elements" {
    var ary = try Array.initCapacity(testAlloc, 4);
    var child = try Array.init(testAlloc);
    child.increment();

    try std.testing.expectEqual(@as(u32, 2), child.refcount);
    try ary.push(testAlloc, Value.from(child));
    ary.decrement(testAlloc);
    try std.testing.expectEqual(@as(u32, 1), child.refcount);
    child.decrement(testAlloc);
}

test "push, pop, and len work" {
    var ary = try Array.init(testAlloc);
    defer ary.decrement(testAlloc);

    try std.testing.expectEqual(@as(usize, 0), ary.len());

    try ary.push(testAlloc, Value.from(1));
    try std.testing.expectEqual(@as(usize, 1), ary.len());

    try ary.push(testAlloc, Value.from(2));
    try std.testing.expectEqual(@as(usize, 2), ary.len());

    try std.testing.expect(ary.pop().?.equals(Value.from(2)));
    try std.testing.expectEqual(@as(usize, 1), ary.len());

    try std.testing.expect(ary.pop().?.equals(Value.from(1)));
    try std.testing.expectEqual(@as(usize, 0), ary.len());

    try std.testing.expectEqual(ary.pop(), null);
}

test "arrays are equal" {
    var ary1 = try Array.init(testAlloc);
    defer ary1.decrement(testAlloc);

    var ary2 = try Array.init(testAlloc);
    defer ary2.decrement(testAlloc);

    try std.testing.expect(ary1.equals(ary1));
    try std.testing.expect(ary1.equals(ary2));

    try ary1.push(testAlloc, Value.from(1));
    try std.testing.expect(ary1.equals(ary1));
    try std.testing.expect(!ary1.equals(ary2));

    try ary2.push(testAlloc, Value.from(1));
    try std.testing.expect(ary1.equals(ary2));
}

test "parse int works" {
    var ary = try Array.init(testAlloc);
    defer ary.decrement(testAlloc);

    try std.testing.expectEqual(@as(IntType, 0), try ary.parseInt());

    try ary.push(testAlloc, Value.from('-'));
    try std.testing.expectEqual(@as(IntType, 0), try ary.parseInt());
    try ary.push(testAlloc, Value.from('1'));
    try std.testing.expectEqual(@as(IntType, -1), try ary.parseInt());
    try ary.push(testAlloc, Value.from('2'));
    try std.testing.expectEqual(@as(IntType, -12), try ary.parseInt());
    try ary.push(testAlloc, Value.from('a'));
    try std.testing.expectEqual(@as(IntType, -12), try ary.parseInt());

    _ = ary.pop();
    var ary2 = try Array.init(testAlloc);
    defer ary2.decrement(testAlloc);
    try ary.push(testAlloc, Value.from(ary2));

    try std.testing.expectError(ParseIntError.NotAnArrayOfInts, ary.parseInt());
}
