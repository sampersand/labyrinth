const std = @import("std");
const Coordinate = @This();
const Vector = @import("Vector.zig");

x: u32 = 0,
y: u32 = 0,

pub const Origin = Coordinate{};

pub const MoveError = error{CoordinateOutOfBounds};
pub fn moveBy(this: Coordinate, by: Vector) MoveError!Coordinate {
    return .{
        .x = std.math.cast(u32, @as(i64, this.x) + @as(i64, by.x)) orelse return error.CoordinateOutOfBounds,
        .y = std.math.cast(u32, @as(i64, this.y) + @as(i64, by.y)) orelse return error.CoordinateOutOfBounds,
    };
}

pub fn sub(this: Coordinate, by: Vector) MoveError!Coordinate {
    return .{
        .x = std.math.cast(u32, @as(i64, this.x) - @as(i64, by.x)) orelse return error.CoordinateOutOfBounds,
        .y = std.math.cast(u32, @as(i64, this.y) - @as(i64, by.y)) orelse return error.CoordinateOutOfBounds,
    };
}

pub fn format(
    this: Coordinate,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.print("({d},{d})", .{ this.x, this.y });
}
