const std = @import("std");

const Coordinate = @This();

x: i32 = 0,
y: i32 = 0,

pub const Origin = Coordinate{};
pub const Up = Coordinate{ .y = -1 };
pub const Down = Coordinate{ .y = 1 };
pub const Left = Coordinate{ .x = -1 };
pub const Right = Coordinate{ .x = 1 };

pub fn eql(left: Coordinate, right: Coordinate) bool {
    return left.x == right.x and left.y == right.y;
}

pub fn add(left: Coordinate, right: Coordinate) Coordinate {
    return .{ .x = left.x + right.x, .y = left.y + right.y };
}

pub fn sub(left: Coordinate, right: Coordinate) Coordinate {
    return .{ .x = left.x - right.x, .y = left.y - right.y };
}

pub fn equals(this: Coordinate, other: Coordinate) bool {
    return this.x == other.x and this.y == other.y;
}

pub fn direction(this: Coordinate) Coordinate {
    return .{
        .x = if (this.x == 0) 0 else @as(i32, if (this.x < 0) -1 else 1),
        .y = if (this.y == 0) 0 else @as(i32, if (this.y < 0) -1 else 1),
    };
}

pub const Direction = enum { left, right };
pub fn rotate(this: Coordinate, dir: Direction) Coordinate {
    return if (dir == .left) Coordinate{
        .x = this.y,
        .y = -this.x,
    } else Coordinate{
        .x = -this.y,
        .y = this.x,
    };
}

test "coord works" {
    var coord = Coordinate.Right;
    std.debug.assert(coord.rotate(.right).equals(Coordinate.Down));
}

pub fn format(
    this: Coordinate,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    _ = fmt;
    _ = options;
    try writer.print("({d},{d})", .{ this.x, this.y });
}
