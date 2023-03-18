const std = @import("std");
const Vector = @This();

x: i32 = 0,
y: i32 = 0,

pub const Up = Vector{ .y = -1 };
pub const Down = Vector{ .y = 1 };
pub const Left = Vector{ .x = -1 };
pub const Right = Vector{ .x = 1 };

pub fn direction(this: Vector) Vector {
    return .{
        .x = if (this.x == 0) 0 else @as(i32, if (this.x < 0) -1 else 1),
        .y = if (this.y == 0) 0 else @as(i32, if (this.y < 0) -1 else 1),
    };
}

pub fn add(left: Vector, right: Vector) Vector {
    return .{ .x = left.x + right.x, .y = left.y + right.y };
}

pub fn sub(left: Vector, right: Vector) Vector {
    return .{ .x = left.x - right.x, .y = left.y - right.y };
}

pub fn scale(this: Vector, scalar: i32) Vector {
    return .{ .x = this.x * scalar, .y = this.y * scalar };
}

pub const Direction = enum { Left, Right };
pub fn rotate(this: Vector, dir: Direction) Vector {
    return if (dir == .Left)
        (.{ .x = this.y, .y = -this.x })
    else
        (.{ .x = -this.y, .y = this.x });
}

test "coord works" {
    var coord = Vector.Right;
    std.debug.assert(coord.rotate(.Right).equals(Vector.Down));
}

pub fn format(
    this: Vector,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.print("({d},{d})", .{ this.x, this.y });
}
