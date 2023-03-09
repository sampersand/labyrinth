const std = @import("std");
const Minotaur = @This();
const Labyrinth = @import("Labyrinth.zig");
const Coordinate = @import("Coordinate.zig");
const Value = @import("value.zig").Value;

position: Coordinate = Coordinate.Origin,
velocity: Coordinate = Coordinate.Right,
stack: std.ArrayList(Value),

pub fn initCapacity(alloc: std.mem.Allocator, cap: usize) std.mem.Allocator.Error!Minotaur {
    return Minotaur{ .stack = try std.ArrayList(Value).initCapacity(alloc, cap) };
}

pub fn deinit(this: *Minotaur) void {
    for (this.stack) |*item| {
        item.deinit();
    }
    this.stack.deinit();
}

pub fn step(this: *Minotaur) void {
    this.position = this.position.add(this.velocity);
}

pub fn unstep(this: *Minotaur) void {
    this.position = this.position.sub(this.velocity);
}

pub fn nth(this: *const Minotaur, idx: usize) ?Value {
    std.debug.assert(idx != 0);
    return if (idx <= this.stack.len) this.stack.items[this.stack.len - idx] else null;
}

pub fn dupn(this: *const Minotaur, idx: usize) ?Value {
    const value = this.nth(idx) orelse return null;
    return value.clone();
}

pub fn push(this: *Minotaur, value: Value) void {
    this.stack.push(value);
}

pub fn pop(this: *Minotaur) ?Value {
    return this.stack.pop();
}

pub fn dump(this: *const Minotaur, writer: anytype) std.os.WriteError!void {
    _ = try writer.write("Minotaur{position=");
    _ = try this.position.dump(writer);
    _ = try writer.write(",velocity=");
    _ = try this.velocity.dump(writer);
    _ = try writer.write(",stack=[");

    for (this.stack.items) |*value, idx| {
        if (idx != 0) {
            _ = try writer.write(", ");
        }
        _ = try value.dump(writer);
    }

    _ = try writer.print("]}}", .{});
}

const PlayResult = union(enum) {
    Continue,
    Error,
    Exit: i32,
};

pub fn play(this: *Minotaur, maze: *Labyrinth) PlayResult {
    _ = this;
    _ = maze;
    return undefined;
}
