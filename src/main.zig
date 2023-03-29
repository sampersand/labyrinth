const std = @import("std");
const Labyrinth = @import("Labyrinth.zig");
const Maze = @import("Maze.zig");
const CommandLineArgs = @import("CommandLineArgs.zig");
const Debugger = @import("Debugger.zig");
const utils = @import("utils.zig");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args = try CommandLineArgs.init(alloc);
    defer args.deinit();
    try args.parse();

    var labyrinth = try args.createLabyrinth();
    defer labyrinth.deinit();

    // try labyrinth.printMaze(std.io.getStdOut().writer());
    // if (true) return 0;

    if (args.options.debug) {
        var debugger = try Debugger.init(&labyrinth);
        defer debugger.deinit();
        try debugger.run();
        return 0;
    } else {
        _ = try labyrinth.play();
        return labyrinth.exit_status orelse 0;
    }
}
