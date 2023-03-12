const std = @import("std");
const Labyrinth = @import("Labyrinth.zig");
const Board = @import("Board.zig");

pub fn main() anyerror!void {
    const alloc = std.heap.page_allocator;
    const args = 

    // \\---"BAB"--"BAB"_D.--P--1+--PQ
    // \\1--59";".P--AaD

    var board = try Board.init(
        \\v     v--QK-=001--.X-----p01--<
        \\|     |                       |
        \\|     |       >--"Fizz"3--v   |
        \\>--1-->--h----|           >--3#--$%!--Kp--Q
        \\         |    >--"Buzz"5--^   J
        \\         |               >.n--^
        \\         >---.3%--:5%--*!I----^
        // \\v  v-----------v
        // \\|  |     |     |
        // \\|  v---<<|>>---v
        // \\|  |   01234   |
        // \\|  |  >RRRRR<  |
        // \\>-->3j>RRRRR<j3<
        // \\   |  >RRRRR<  |
        // \\   |   56789   |
        // \\   ^---<<|>>---^
        // \\   |     |     |
        // \\   ^-----------^
    , alloc);

    var labyrinth = b: {
        errdefer board.deinit();
        break :b try Labyrinth.init(board, alloc);
    };
    defer labyrinth.deinit();
    _ = try labyrinth.play();
}
