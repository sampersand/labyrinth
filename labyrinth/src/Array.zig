const std = @import("std");
const Allocator = std.mem.Allocator;
const Array = @This();
const Value = @import("value.zig").Value;
const IntType = @import("types.zig").IntType;

refcount: u32,
eles: std.ArrayListUnmanaged(Value),

/// Creates a new `Array` with no starting capacity.
pub fn init(alloc: Allocator) Allocator.Error!*Array {
    return initCapacity(alloc, 0);
}

/// Creates a new `Array` with the given starting capacity.
pub fn initCapacity(alloc: Allocator, cap: usize) Allocator.Error!*Array {
    var ary = try alloc.create(Array);
    errdefer alloc.destroy(ary);

    ary.refcount = 1;
    ary.eles = try std.ArrayListUnmanaged(Value).initCapacity(alloc, cap);
    return ary;
}

/// Increments the refcount by one.
pub inline fn increment(ary: *Array) void {
    ary.refcount += 1;
}

/// Decrements the refcount by one; if it reaches zero, the array is deallocated.
pub fn decrement(ary: *Array, alloc: Allocator) void {
    std.debug.assert(ary.refcount != 0);
    ary.refcount -= 1;

    if (ary.refcount == 0) ary.deinitNoCheck(alloc);
}

/// Deinitializes `ary`. `refcount` must be zero; if it's not, call `deinitNoCheck`.
pub inline fn deinit(ary: *Array, alloc: Allocator) void {
    std.debug.assert(ary.refcount == 0);
    ary.deinitNoCheck(alloc);
}

/// Deinitializes the Array without checking to make sure its refcount is zero.
pub fn deinitNoCheck(ary: *Array, alloc: Allocator) void {
    for (ary.eles.items) |value|
        value.deinit(alloc);

    ary.eles.deinit(alloc);
    alloc.destroy(ary);
}

/// Pushes `value` onto the end of the allocator.
pub inline fn push(ary: *Array, alloc: Allocator, value: Value) Allocator.Error!void {
    try ary.eles.append(alloc, value);
}

/// Pops the last element off the end of the array.
pub inline fn pop(ary: *Array) ?Value {
    return ary.eles.popOrNull();
}

/// Returns how many elements are currently in the array.
pub inline fn len(ary: *const Array) usize {
    return ary.eles.items.len;
}

/// Sees whether `ary` has the same elements as `other`.
pub fn equals(ary: *const Array, other: *const Array) bool {
    // if they're identical, they're the same.
    if (ary == other)
        return true;

    // If their lengths arent equal theyre not the same.
    if (ary.len() != other.len())
        return false;

    // If any item isn't the same, then the arrays arent equivalent
    for (ary.eles.items) |value, index| {
        if (!value.equals(other.eles.items[index]))
            return false;
    }

    // Every value's compared the same so theyre equal.
    return true;
}

/// Errors that can happen when `parseInt` is called.
pub const ParseIntError = error{ NotAnArrayOfInts, Overflow };

/// Must be called on an array of ints; Interprets it as a string, and returns the int value
/// associated.
pub fn parseInt(ary: *const Array) ParseIntError!IntType {
    if (ary.len() == 0) return 0;

    const minus = comptime Value.from('-');
    var int: IntType = 0;
    var sign: IntType = 1;
    var idx: usize = 0;

    if (ary.eles.items[idx].equals(minus)) {
        sign = -1;
        idx += 1;
    }

    while (idx < ary.len()) : (idx += 1) {
        switch (ary.eles.items[idx].classify()) {
            .int => |i| {
                if (i < '0' or '9' < i) break;
                int = try std.math.add(IntType, try std.math.mul(IntType, int, 10), i - '0');
            },
            else => return error.NotAnArrayOfInts,
        }
    }

    return int * sign;
}

pub fn format(
    ary: *const Array,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.writeAll("[");

    for (ary.eles.items) |value, idx| {
        if (idx != 0)
            try writer.writeAll(", ");
        try writer.print("{}", .{value});
    }

    try writer.writeAll("]");
}

/// Calls `print` on every element in `ary`, writing a newline if it's an array.
pub fn print(ary: *const Array, writer: anytype) Value.PrintError!void {
    for (ary.eles.items) |value| {
        try value.print(writer);
        if (value.classify() == .ary)
            try writer.writeAll("\n");
    }
}

const test_alloc = std.testing.allocator;
test "refcount defaults to 1, len starts as 0" {
    var ary = try Array.init(test_alloc);
    defer ary.deinitNoCheck(test_alloc);

    try std.testing.expectEqual(@as(u32, 1), ary.refcount);
    try std.testing.expectEqual(@as(usize, 0), ary.len());
}

test "refcount works as expected" {
    var ary = try Array.init(test_alloc);

    try std.testing.expectEqual(@as(u32, 1), ary.refcount);
    ary.increment();
    try std.testing.expectEqual(@as(u32, 2), ary.refcount);
    ary.increment();
    try std.testing.expectEqual(@as(u32, 3), ary.refcount);

    ary.decrement(undefined);
    try std.testing.expectEqual(@as(u32, 2), ary.refcount);
    ary.decrement(undefined);
    try std.testing.expectEqual(@as(u32, 1), ary.refcount);
    ary.decrement(test_alloc);
}

test "deinit also deinits elements" {
    var ary = try Array.initCapacity(test_alloc, 4);
    var child = try Array.init(test_alloc);
    child.increment();

    try std.testing.expectEqual(@as(u32, 2), child.refcount);
    try ary.push(test_alloc, Value.from(child));
    ary.decrement(test_alloc);
    try std.testing.expectEqual(@as(u32, 1), child.refcount);
    child.decrement(test_alloc);
}

test "push, pop, and len work" {
    var ary = try Array.init(test_alloc);
    defer ary.decrement(test_alloc);

    try std.testing.expectEqual(@as(usize, 0), ary.len());

    try ary.push(test_alloc, Value.from(1));
    try std.testing.expectEqual(@as(usize, 1), ary.len());

    try ary.push(test_alloc, Value.from(2));
    try std.testing.expectEqual(@as(usize, 2), ary.len());

    try std.testing.expect(ary.pop().?.equals(Value.from(2)));
    try std.testing.expectEqual(@as(usize, 1), ary.len());

    try std.testing.expect(ary.pop().?.equals(Value.from(1)));
    try std.testing.expectEqual(@as(usize, 0), ary.len());

    try std.testing.expectEqual(ary.pop(), null);
}

test "arrays are equal" {
    var ary1 = try Array.init(test_alloc);
    defer ary1.decrement(test_alloc);

    var ary2 = try Array.init(test_alloc);
    defer ary2.decrement(test_alloc);

    try std.testing.expect(ary1.equals(ary1));
    try std.testing.expect(ary1.equals(ary2));

    try ary1.push(test_alloc, Value.from(1));
    try std.testing.expect(ary1.equals(ary1));
    try std.testing.expect(!ary1.equals(ary2));

    try ary2.push(test_alloc, Value.from(1));
    try std.testing.expect(ary1.equals(ary2));
}

test "parse int works" {
    var ary = try Array.init(test_alloc);
    defer ary.decrement(test_alloc);

    try std.testing.expectEqual(@as(IntType, 0), try ary.parseInt());

    try ary.push(test_alloc, Value.from('-'));
    try std.testing.expectEqual(@as(IntType, 0), try ary.parseInt());
    try ary.push(test_alloc, Value.from('1'));
    try std.testing.expectEqual(@as(IntType, -1), try ary.parseInt());
    try ary.push(test_alloc, Value.from('2'));
    try std.testing.expectEqual(@as(IntType, -12), try ary.parseInt());
    try ary.push(test_alloc, Value.from('a'));
    try std.testing.expectEqual(@as(IntType, -12), try ary.parseInt());

    _ = ary.pop();
    var ary2 = try Array.init(test_alloc);
    defer ary2.decrement(test_alloc);
    try ary.push(test_alloc, Value.from(ary2));

    try std.testing.expectError(ParseIntError.NotAnArrayOfInts, ary.parseInt());
}
