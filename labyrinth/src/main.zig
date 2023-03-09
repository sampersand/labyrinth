const std = @import("std");
const Labyrinth = @import("Labyrinth.zig");
const Board = @import("Board.zig");

pub fn main() anyerror!void {
    var maze = try Labyrinth.init(Board{}, std.testing.allocator);
    defer maze.deinit();
    try maze.dump(std.io.getStdOut().writer());
    _ = maze;
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
