const std = @import("std");
const Vector = @This();

x: i32 = 0,
y: i32 = 0,

pub const Up = Vector{ .y = -1 };
pub const Down = Vector{ .y = 1 };
pub const Left = Vector{ .x = -1 };
pub const Right = Vector{ .x = 1 };

pub fn direction(this: Vector) Vector {
    return .{ .x = std.math.sign(this.x), .y = std.math.sign(this.y) };
}

pub fn add(this: Vector, right: Vector) Vector {
    return .{ .x = this.x + right.x, .y = this.y + right.y };
}

pub fn sub(this: Vector, right: Vector) Vector {
    return this.add(right.scale(-1));
}

pub fn scale(this: Vector, scalar: i32) Vector {
    return .{ .x = this.x * scalar, .y = this.y * scalar };
}

pub const Direction = enum { Left, Right };
pub fn rotate(this: Vector, dir: Direction) Vector {
    return if (dir == .Left) .{ .x = this.y, .y = -this.x } else .{ .x = -this.y, .y = this.x };
}

// test "coord works" {
// var coord = Vector.Right;
// std.debug.assert(coord.rotate(.Right).equals(Vector.Down));
// }

pub fn format(
    this: Vector,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.print("({d},{d})", .{ this.x, this.y });
}
