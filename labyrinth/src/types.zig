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
        ary = try ary.prependNoIncrement(alloc, Value.from(@intCast(IntType, byte)));
        if (idx == 0) break;
    }

    return ary;
}

pub fn format(int: IntType, comptime fmt: []const u8, writer: anytype) !void {
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
}
