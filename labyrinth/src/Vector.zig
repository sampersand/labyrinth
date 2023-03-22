const std = @import("std");
const build_options = @import("build-options");

/// `Vector`s are `Coordinate`s with directions associated with them.
///
/// They are used within `Minotaur` to keep track of the velocity.
const Vector = @This();
const VectorInt = i32;
// if (build_options.max_velocity) |max|
//     std.math.IntFittingRange(0, max)
// else
//     i32;

/// The x coordinate of the vector.
x: VectorInt = 0,

/// The y coordinate of the vector.
y: VectorInt = 0,

/// A Vector that points directly upwards.
pub const Up = Vector{ .y = -1 };

/// A Vector that points directly downwards.
pub const Down = Vector{ .y = 1 };

/// A Vector that points directly left.
pub const Left = Vector{ .x = -1 };

/// A Vector that points directly right.
pub const Right = Vector{ .x = 1 };

/// Gets the direction the `Vector` is currently pointing in.
///
/// This clamps the x and y values to the values -1, 0, or 1.
fn direction(this: Vector) Vector {
    return .{ .x = std.math.sign(this.x), .y = std.math.sign(this.y) };
}

pub fn speedUp(this: Vector) Vector {
    return this.add(this.direction());
}

pub fn slowDown(this: Vector) Vector {
    const dir = this.sub(this.direction());
    return if (dir.x == 0 and dir.y == 0) this.scale(-1) else dir;
}

/// Returns the sum of `this` and `right` as a new vector.
pub fn add(this: Vector, right: Vector) Vector {
    const ret = Vector{ .x = this.x + right.x, .y = this.y + right.y };

    if (build_options.max_velocity) |max| {
        std.debug.assert(std.math.abs(ret.x) <= max);
        std.debug.assert(std.math.abs(ret.y) <= max);
    }

    return ret;
}

pub inline fn sub(this: Vector, right: Vector) Vector {
    return this.add(right.scale(-1));
}

pub inline fn scale(this: Vector, scalar: i32) Vector {
    return .{ .x = this.x * scalar, .y = this.y * scalar };
}

pub const Direction = enum { left, right };
pub fn rotate(this: Vector, dir: Direction) Vector {
    return switch (dir) {
        .left => .{ .x = this.y, .y = -this.x },
        .right => .{ .x = -this.y, .y = this.x },
    };
}

pub fn format(
    this: Vector,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.print("({d},{d})", .{ this.x, this.y });
}
