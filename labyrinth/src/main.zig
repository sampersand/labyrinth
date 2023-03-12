const std = @import("std");
const Labyrinth = @import("Labyrinth.zig");
const Board = @import("Board.zig");

pub fn main() anyerror!void {
    const alloc = std.heap.page_allocator;

    var board = try Board.init(
        \\---"BAB"--"BAB"_D.--P--1+--PQ
        \\1--59";".P--AaD
        \\v  v-----------v
        \\|  |     |     |
        \\|  v---<<|>>---v
        \\|  |   01234   |
        \\|  |  >RRRRR<  |
        \\>-->3j>RRRRR<j3<
        \\   |  >RRRRR<  |
        \\   |   56789   |
        \\   ^---<<|>>---^
        \\   |     |     |
        \\   ^-----------^
    , alloc);

    var labyrinth = b: {
        errdefer board.deinit();
        break :b try Labyrinth.init(board, alloc);
    };
    defer labyrinth.deinit();
    _ = try labyrinth.play();
}
