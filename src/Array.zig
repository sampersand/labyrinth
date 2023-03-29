const std = @import("std");
const Allocator = std.mem.Allocator;
const Value = @import("Value.zig");
const IntType = @import("types.zig").IntType;
const utils = @import("utils.zig");

const Array = @This();

refcount: u32 = 1,
next: ?*Array = null,
value: Value,

var _empty = Array{ .value = undefined };
pub const empty: *Array = &_empty;

/// Creates a new `Array` with no starting capacity.
pub fn init(alloc: Allocator, value: Value) Allocator.Error!*Array {
    var ary = try alloc.create(Array);
    ary.* = .{ .value = value };
    return ary;
}

/// Deinitializes `ary`. `refcount` must be zero.
pub fn deinit(ary: *Array, alloc: Allocator) void {
    if (ary == empty) return;

    std.debug.assert(ary.refcount == 0);

    if (ary.next) |next| next.decrement(alloc);
    ary.value.deinit(alloc);
    alloc.destroy(ary);
}

pub fn prependNoIncrement(ary: *Array, alloc: Allocator, value: Value) Allocator.Error!*Array {
    var new = try init(alloc, value);
    new.next = ary;
    return new;
}

// pub fn perepend(ary: *Array, alloc: Allocator, value: Value) Allocator.Error!*Array {
//     var new = try ary.prependNoIncrement(alloc, value);
//     ary.increment();
//     return new;
// }

/// Increments the refcount by one.
pub inline fn increment(ary: *Array) void {
    if (ary == empty) {
        ary.refcount +%= 1;
    } else {
        ary.refcount += 1;
    }
}

/// Decrements the refcount by one; if it reaches zero, the array is deallocated.
pub fn decrement(ary: *Array, alloc: Allocator) void {
    if (ary == empty) return;

    ary.refcount -= 1;

    if (ary.refcount == 0) ary.deinit(alloc);
}

pub fn cons(ary: *Array, alloc: Allocator, end: *Array) Allocator.Error!*Array {
    // no need to decrement counts
    if (ary.isEmpty()) return end;
    if (end.isEmpty()) return ary;
    _ = alloc;

    return empty;
    // var begin = Array.
    // var begin = try ary.deepClone(alloc);
    // const dup = try ary.deepClone(minotaur.allocator);
    // var dup_iter = dup.iter();
}
pub const Iterator = struct {
    array: *const Array,

    pub fn isDone(iterator: *const Iterator) bool {
        return iterator.array.isEmpty();
    }

    pub fn next(iterator: *Iterator) ?Value {
        if (iterator.isDone()) return null;

        defer if (iterator.array.next) |n| {
            iterator.array = n;
        };

        return iterator.array.value;
    }
};

pub inline fn iter(ary: *const Array) Iterator {
    return .{ .array = ary };
}

pub fn reverse(ary: *const Array, alloc: Allocator) Allocator.Error!*Array {
    var current = empty;
    var iterator = ary.iter();
    while (iterator.next()) |value| {
        current = try current.prependNoIncrement(alloc, value.clone());
    }
    return current;
}

pub inline fn isEmpty(ary: *const Array) bool {
    return ary == empty;
}

/// Returns how many elements are currently in the array.
pub fn len(ary: *const Array) usize {
    var iterator = ary.iter();
    var l: usize = 0;
    while (iterator.next() != null) l += 1;
    return l;
}

/// Sees whether `ary` has the same elements as `other`.
pub fn equals(ary: *const Array, other: *const Array) bool {
    if (ary == other) return true;

    var liter = ary.iter();
    var riter = other.iter();

    while (liter.next()) |left| {
        const right = riter.next() orelse return false;
        if (!left.equals(right)) return false;
    }

    return riter.next() == null;
}

/// Errors that can happen when `parseInt` is called.
pub const ParseIntError = error{ NotAnArrayOfInts, Overflow };

/// Must be called on an array of ints; Interprets it as a string, and returns the int value
/// associated.
pub fn parseInt(ary: *const Array) ParseIntError!IntType {
    if (ary.isEmpty()) return 0;

    var int: IntType = 0;
    var sign: ?IntType = null;
    var iterator = ary.iter();

    while (iterator.next()) |val| {
        switch (val.classify()) {
            .int => |i| {
                const byte = std.math.cast(u8, i) orelse break;

                if (sign == null) {
                    if (std.ascii.isWhitespace(byte)) continue;
                    if (byte == '-') {
                        sign = -1;
                        continue;
                    }
                    sign = 1;
                }

                const digit = std.fmt.charToDigit(byte, 10) catch break;
                int = try std.math.add(IntType, try std.math.mul(IntType, int, 10), digit);
            },
            else => return error.NotAnArrayOfInts,
        }
    }
    return std.math.mul(IntType, int, sign orelse 1);

    // if (ary.value.equals(minus)) {
    //     sign = -1;
    //     curr = curr.?.next;
    // }

    // while (if (curr == null) null else (curr orelse unreachable).next) |next| : (curr = next) {
    //     switch (next.value.classify()) {
    //         .int => |i| {
    //             if (i < '0' or '9' < i) break;
    //             int = try std.math.add(IntType, try std.math.mul(IntType, int, 10), i - '0');
    //         },
    //         else => return error.NotAnArrayOfInts,
    //     }
    // }

    // return int * sign;
}

pub fn fromString(alloc: Allocator, string: []const u8) Allocator.Error!*Array {
    var ary = Array.empty;
    var idx = string.len; // TODO: std.mem.reverseIterator when it comes out.

    while (true) {
        idx -= 1;
        const byte = string[idx];
        ary = try ary.prependNoIncrement(alloc, Value.from(@intCast(IntType, byte)));
        if (idx == 0) break;
    }

    return ary;
}

pub fn format(
    ary: *const Array,
    comptime fmt: []const u8,
    opts: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    const which = comptime utils.FmtEnum.mustFrom(fmt);
    var iterator = ary.iter();
    switch (which) {
        .s, .d => {
            while (iterator.next()) |value| {
                try value.format(fmt, opts, writer);
                switch (which) {
                    .s => if (value.classify() == .ary) try writer.writeByte('\n'),
                    .d => if (!iterator.isDone()) try writer.writeByte(' '),
                    .any => unreachable,
                }
            }
        },
        .any => {
            try writer.writeByte('[');

            var first = true;
            while (iterator.next()) |value| {
                if (!first) try writer.writeAll(", ");
                first = false;
                try writer.print("{}", .{value});
            }

            try writer.writeByte(']');
        },
    }
}

// const test_alloc = std.testing.allocator;
// test "refcount defaults to 1, len starts as 0" {
//     var ary = try Array.init(test_alloc);
//     defer ary.decrement(test_alloc);

//     try std.testing.expectEqual(@as(u32, 1), ary.refcount);
//     try std.testing.expectEqual(@as(usize, 0), ary.len());
// }

// test "refcount works as expected" {
//     var ary = try Array.init(test_alloc);

//     try std.testing.expectEqual(@as(u32, 1), ary.refcount);
//     ary.increment();
//     try std.testing.expectEqual(@as(u32, 2), ary.refcount);
//     ary.increment();
//     try std.testing.expectEqual(@as(u32, 3), ary.refcount);

//     ary.decrement(undefined);
//     try std.testing.expectEqual(@as(u32, 2), ary.refcount);
//     ary.decrement(undefined);
//     try std.testing.expectEqual(@as(u32, 1), ary.refcount);
//     ary.decrement(test_alloc);
// }

// test "deinit also deinits elements" {
//     var ary = try Array.initCapacity(test_alloc, 4);
//     var child = try Array.init(test_alloc);
//     child.increment();

//     try std.testing.expectEqual(@as(u32, 2), child.refcount);
//     try ary.push(test_alloc, Value.from(child));
//     ary.decrement(test_alloc);
//     try std.testing.expectEqual(@as(u32, 1), child.refcount);
//     child.decrement(test_alloc);
// }

// test "push, pop, and len work" {
//     var ary = try Array.init(test_alloc);
//     defer ary.decrement(test_alloc);

//     try std.testing.expectEqual(@as(usize, 0), ary.len());

//     try ary.push(test_alloc, Value.from(1));
//     try std.testing.expectEqual(@as(usize, 1), ary.len());

//     try ary.push(test_alloc, Value.from(2));
//     try std.testing.expectEqual(@as(usize, 2), ary.len());

//     try std.testing.expect(ary.pop().?.equals(Value.from(2)));
//     try std.testing.expectEqual(@as(usize, 1), ary.len());

//     try std.testing.expect(ary.pop().?.equals(Value.from(1)));
//     try std.testing.expectEqual(@as(usize, 0), ary.len());

//     try std.testing.expectEqual(ary.pop(), null);
// }

// test "arrays are equal" {
//     var ary1 = try Array.init(test_alloc);
//     defer ary1.decrement(test_alloc);

//     var ary2 = try Array.init(test_alloc);
//     defer ary2.decrement(test_alloc);

//     try std.testing.expect(ary1.equals(ary1));
//     try std.testing.expect(ary1.equals(ary2));

//     try ary1.push(test_alloc, Value.from(1));
//     try std.testing.expect(ary1.equals(ary1));
//     try std.testing.expect(!ary1.equals(ary2));

//     try ary2.push(test_alloc, Value.from(1));
//     try std.testing.expect(ary1.equals(ary2));
// }

// test "parse int works" {
//     var ary = try Array.init(test_alloc);
//     defer ary.decrement(test_alloc);

//     try std.testing.expectEqual(@as(IntType, 0), try ary.parseInt());

//     try ary.push(test_alloc, Value.from('-'));
//     try std.testing.expectEqual(@as(IntType, 0), try ary.parseInt());
//     try ary.push(test_alloc, Value.from('1'));
//     try std.testing.expectEqual(@as(IntType, -1), try ary.parseInt());
//     try ary.push(test_alloc, Value.from('2'));
//     try std.testing.expectEqual(@as(IntType, -12), try ary.parseInt());
//     try ary.push(test_alloc, Value.from('a'));
//     try std.testing.expectEqual(@as(IntType, -12), try ary.parseInt());

//     _ = ary.pop();
//     var ary2 = try Array.init(test_alloc);
//     defer ary2.decrement(test_alloc);
//     try ary.push(test_alloc, Value.from(ary2));

//     try std.testing.expectError(ParseIntError.NotAnArrayOfInts, ary.parseInt());
// }
