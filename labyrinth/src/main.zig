const std = @import("std");
const Labyrinth = @import("Labyrinth.zig");
const Board = @import("Board.zig");
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

    // try labyrinth.printBoard(std.io.getStdOut().writer());
    // if (true) return 0;

    if (args.options.debug) {
        var debugger = Debugger.init(&labyrinth);
        try debugger.run();
        return 0;
    } else {
        _ = try labyrinth.play();
        return labyrinth.exitStatus orelse 0;
    }
}
