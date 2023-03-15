const std = @import("std");
const Labyrinth = @import("Labyrinth.zig");
const Board = @import("Board.zig");
const CommandLineArgs = @import("CommandLineArgs.zig");

fn readEntireFile(alloc: std.mem.Allocator, path: []const u8) ![]u8 {
    std.debug.print("[{}]\n", .{std.fs.cwd()});
    var file = try std.fs.cwd().openFile(path, .{});
    return file.reader().readAllAlloc(alloc, std.math.maxInt(usize));
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args = try CommandLineArgs.init(alloc);
    defer args.deinit();
    try args.parse();

    // while (args.next()) |arg| {
    //     if (std.mem.eql(u8, arg, "-h")) return;
    //     std.debug.print("arg={s}\n", .{arg});
    // }

    const contents = try readEntireFile(alloc, "examples/helloworld.lb");
    defer alloc.free(contents);
    var board = try Board.init(alloc, contents);

    //     \\1--"ABC"--+--PQ
    //     \\--&
    //     \\v     v--QK-=001--.X-----p01--<
    //     \\|     |                       |
    //     \\|     |       >--"Fizz"3--v   |
    //     \\>--1-->--h----|           >--3#--$%!--Kp--Q
    //     \\         |    >-Z"Buzz"5--^   J
    //     \\         |               >.n--^
    //     \\         >---.3%--:5%--*!I----^
    //     // \\v  v-----------v
    //     // \\|  |     |     |
    //     // \\|  v---<<|>>---v
    //     // \\|  |   01234   |
    //     // \\|  |  >RRRRR<  |
    //     // \\>-->3j>RRRRR<j3<
    //     // \\   |  >RRRRR<  |
    //     // \\   |   56789   |
    //     // \\   ^---<<|>>---^
    //     // \\   |     |     |
    //     // \\   ^-----------^
    // , alloc);

    var labyrinth = b: {
        errdefer board.deinit(alloc);
        break :b try Labyrinth.init(board, alloc);
    };
    defer labyrinth.deinit();
    _ = try labyrinth.play();
}
