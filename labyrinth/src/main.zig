const std = @import("std");
const Labyrinth = @import("Labyrinth.zig");
const Board = @import("Board.zig");
const CommandLineArgs = @import("CommandLineArgs.zig");
const utils = @import("utils.zig");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var labyrinth = blk: {
        var args = try CommandLineArgs.init(alloc);
        defer args.deinit();

        try args.parse();
        break :blk try args.createLabyrinth();
    };

    defer labyrinth.deinit();

    _ = try labyrinth.play();
    return labyrinth.exitStatus orelse 0;
}
