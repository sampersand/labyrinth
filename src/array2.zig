const std = @import("std");
const Value = @import("Value.zig");
const Allocator = std.mem.Allocator;

pub const ArrayClassification = union(enum) { string: std.meta.fieldInfo(std.meta.fieldInfo(Array, "data").a) };

pub const Array = extern struct {
    comptime {
        std.debug.assert(@sizeOf(@This()) == total_size);
    }

    const total_size = @sizeOf(u64) * 4;
    const header_size = @sizeOf(u32);
    const body_size = total_size - header_size;
    const max_embed_len = @divTrunc(body_size - @sizeOf(u8), @sizeOf(Value.DataType));

    header: packed struct(u32) {
        comptime {
            std.debug.assert(@sizeOf(@This()) == header_size);
        }

        refcount: u30,
        tag: enum(u2) { string, alloc, embed, cons },
    } align(8),

    data: extern union {
        string: extern struct {
            len: u8,
            embed: [body_size - @sizeOf(u8)]u8,
        },
        alloc: extern struct {
            _: [@alignOf(usize) - header_size]u8 = undefined,
            len: usize align(4),
            ptr: [*]Value align(4),
        },
        embed: extern struct {
            len: u8,
            data: [max_embed_len]Value.DataType align(4),
        },
        cons: extern struct {
            _: [@alignOf(*Array) - header_size]u8 = undefined,
            left: *Array align(4),
            right: *Array align(4),
        },
    },

    const _empty = Array{
        .header = .{ .tag = .string },
        .data = .{ .string = .{ .len = 0, .data = undefined } },
    };
    pub const empty = &_empty;

    fn allocate(alloc: Allocator) Allocator.Error!*Array {
        var array = try alloc.create(Array);
        array.header.refcount = 1;
        return array;
    }

    pub fn initCapacity(alloc: Allocator, len: usize) Allocator.Error!*Array {
        var ary = try allocate(alloc);
        errdefer ary.deinit(alloc);

        ary.data = if (len <= max_embed_len) .{
            .embed = .{ .len = 0, .data = undefined },
        } else .{
            .alloc = .{ .len = 0, .ptr = try alloc.allocate(Value, len) },
        };

        return ary;
    }

    // pub fn fromOwnedString(string: []const u8)

};
pub fn main() void {
    const x: Array = .{ .header = undefined, .data = undefined };
    _ = x;
}

// const Array = @This();
// refcount: u32,
// data: union {
//     const size = 16;

//     array: []Value,
//     cons: struct { l: *Array, r: *Array },
//     string: struct {
//         const LenType = std.math.IntFittingRange(0, size);
//         len: LenType,
//         data: [size - @sizeOf(LenType)]u8,
//     },

//     comptime {
//         std.debug.assert(@sizeOf(@This()) == size);
//     }
// },

// // pub const empty: *Array = null;
