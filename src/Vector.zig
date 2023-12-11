//! `Vector`s are `Coordinate`s with directions associated with them.
//!
//! They are used within `Minotaur` to keep track of the velocity.

const std = @import("std");
const build_options = @import("build-options");

pub const VecInt = std.meta.Int(.signed, build_options.vector_bits);
const Vector = @This();

/// The x coordinate of the vector.
x: VecInt = 0,

/// The y coordinate of the vector.
y: VecInt = 0,

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
fn direction(vec: Vector) Vector {
    return .{ .x = std.math.sign(vec.x), .y = std.math.sign(vec.y) };
}

/// Increases the speed of `vec` by one unit.
pub fn speedUp(vec: Vector) Vector {
    return vec.add(vec.direction());
}

/// Decreases the speed of `vec` by one unit. If this makes it zero, it turns around instead.
pub fn slowDown(vec: Vector) Vector {
    const dir = vec.sub(vec.direction());
    return if (dir.x == 0 and dir.y == 0) vec.scale(-1) else dir;
}

/// Returns the sum of `vec` and `right` as a new vector.
pub fn add(vec: Vector, right: Vector) Vector {
    const ret = Vector{ .x = vec.x + right.x, .y = vec.y + right.y };

    if (build_options.max_velocity != 0) {
        if (build_options.max_velocity < std.math.abs(ret.x)) @panic("velocity too high");
        if (build_options.max_velocity < std.math.abs(ret.y)) @panic("velocity too high");
    }

    return ret;
}

/// Returns `right` subtracted from `vec.`
pub inline fn sub(vec: Vector, right: Vector) Vector {
    return vec.add(right.scale(-1));
}

/// Returns `vec` scaled up by `scalar`.
pub inline fn scale(vec: Vector, scalar: VecInt) Vector {
    return .{ .x = vec.x * scalar, .y = vec.y * scalar };
}

/// The direction to rotate.
pub const Direction = enum { left, right };

/// Returns a `vec` rotated by `dir`.
pub fn rotate(vec: Vector, dir: Direction) Vector {
    return switch (dir) {
        .left => .{ .x = vec.y, .y = -vec.x },
        .right => .{ .x = -vec.y, .y = vec.x },
    };
}

/// Prints `vec` to stdout.
pub fn format(
    vec: Vector,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.print("({d},{d})", .{ vec.x, vec.y });
}
