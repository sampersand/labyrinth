const std = @import("std");
const types = @import("Types.zig");

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

pub fn direction(this: Coordinate) Coordinate {
    return .{
        .x = if (this.x == 0) 0 else if (this.x < 0) -1 else 1,
        .y = if (this.y == 0) 0 else if (this.y < 0) -1 else 1,
    };
}

const Direction = enum { left, right };
pub fn rotate(this: Coordinate, direction: Direction) Coordinate {
    return if (direction == .left) .{
        .x = this.y,
        .y = -this.x,
    } else .{
        .x = -this.y,
        .y = this.x,
    };
}

pub fn dump(this: Coordinate, writer: anytype) std.os.WriteError!void {
    try writer.print("({d},{d})", .{ this.x, this.y });
}
