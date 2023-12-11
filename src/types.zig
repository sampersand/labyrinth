const std = @import("std");
const utils = @import("utils.zig");
const Array = @import("Array.zig");
const Value = @import("Value.zig");
const Allocator = std.mem.Allocator;
pub const IntType = i63;

pub fn toArray(int: IntType, alloc: Allocator) Allocator.Error!*Array {
    var buf: [255]u8 = undefined; // 255 is plenty.
    const bytes = std.fmt.bufPrint(&buf, "{d}", .{int}) catch unreachable;
    var ary = Array.empty;

    // todo: use std.mem.reverseIterator
    var idx = bytes.len;
    while (true) {
        idx -= 1;
        const byte = buf[idx];
        ary = try ary.prependNoIncrement(alloc, Value.from(@as(IntType, @intCast(byte))));
        if (idx == 0) break;
    }

    return ary;
}
