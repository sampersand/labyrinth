const std = @import("std");
const Coordinate = @This();
const Vector = @import("Vector.zig");

pub const CoordInt = u32;

/// The x coordinate.
x: CoordInt = 0,

/// The y coordinate.
y: CoordInt = 0,

/// The origin, ie `(0,0)`.
pub const Origin = Coordinate{};

/// A problem that can occur during `moveBy`.
pub const MoveError = error{CoordinateOutOfBounds};

/// Moves the `coord` by `by` units, returning a `MoveError` if there was a problem with it.
pub fn moveBy(coord: Coordinate, by: Vector) MoveError!Coordinate {
    return Coordinate{
        .x = std.math.cast(CoordInt, @as(i64, coord.x) + @as(i64, by.x)) orelse return error.CoordinateOutOfBounds,
        .y = std.math.cast(CoordInt, @as(i64, coord.y) + @as(i64, by.y)) orelse return error.CoordinateOutOfBounds,
    };
}

/// Prints out `(x,y)`.
pub fn format(
    coord: Coordinate,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.print("({d},{d})", .{ coord.x, coord.y });
}
