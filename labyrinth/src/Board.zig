const std = @import("std");
const Allocator = std.mem.Allocator;
const Function = @import("function.zig").Function;
const Minotaur = @import("Minotaur.zig");
const Coordinate = @import("Coordinate.zig");
const Board = @This();

lines: std.ArrayList([]u8),

pub const InitBoardError = Allocator.Error || Function.ValidateError;

pub fn init(source: []const u8, alloc: Allocator) InitBoardError!Board {
    // allocate the board
    var board = Board{
        .lines = try std.ArrayList([]u8).initCapacity(alloc, 8),
    };
    // if there's an error anywhere below this, deallocate the board before returning.
    errdefer board.deinit();

    // split the source into newlines
    var iter = std.mem.split(u8, source, "\n");
    while (iter.next()) |line| {
        // duplicate the line that we just got (as it's a `[]const u8`)
        var dup = try alloc.dupe(u8, line);
        errdefer alloc.free(dup); // if there's a problem in the next statement, free the dup line.

        // Add it to the end of the list of lines.
        try board.lines.append(@ptrCast([]u8, dup));
    }

    return board;
}

pub fn deinit(this: *Board) void {
    for (this.lines.items) |line| {
        this.lines.allocator.free(line);
    }

    this.lines.deinit();
}

pub fn format(
    this: *const Board,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    _ = fmt;
    _ = options;
    _ = writer;
    _ = this;
}

pub const GetError = error{IntOutOfBounds};
pub fn get(this: *const Board, pos: Coordinate) GetError!u8 {
    // std.debug.print("{d}|{d}\n", pos);
    const y = std.math.cast(usize, pos.y) orelse return error.IntOutOfBounds;
    const x = std.math.cast(usize, pos.x) orelse return error.IntOutOfBounds;

    if (this.lines.items.len <= y) {
        return error.IntOutOfBounds;
    }

    const line = this.lines.items[y];
    const byte = if (line.len <= x) return error.IntOutOfBounds else line[x];

    return byte;
}

pub fn printBoard(this: *const Board, minotaurs: []Minotaur, writer: anytype) std.os.WriteError!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    // defer allocator.dealloc();
    var indices = std.ArrayList(usize).initCapacity(allocator, minotaurs.len) catch @panic("oops?");

    for (this.lines.items) |line, col| {
        indices.clearRetainingCapacity();

        for (minotaurs) |minotaur| {
            if (minotaur.position.y == col) {
                indices.append(@intCast(usize, minotaur.position.x)) catch unreachable;
            }
        }

        if (indices.items.len == 0) {
            try writer.print("{s}\n", .{line});
            continue;
        }

        std.sort.sort(usize, indices.items, {}, std.sort.asc(usize));
        var i: usize = 0;
        while (i < indices.items.len) : (i += 1) {
            if (i != 0 and indices.items[i] == indices.items[i - 1]) continue;
            const start = if (i == 0) 0 else indices.items[i - 1] + 1;

            const len = indices.items[i] - start;
            try writer.print("{s}\x1B[7m{c}\x1B[0m", .{ line[start .. start + len], line[indices.items[i]] });
        }
        try writer.print("{s}\n", .{line[indices.items[indices.items.len - 1] + 1 ..]});
    }

    //         qsort(indices, nindices, sizeof(int), cmp_int);
    //         for (int i = 0; i < nindices; ++i) {
    //             if (i && indices[i] == indices[i-1]) continue;
    //             int start = (i == 0 ? 0 : indices[i - 1] + 1);
    //             printf("%.*s\033[7m%c\033[0m",
    //                 indices[i] - start, b->fns[col] + start, b->fns[col][indices[i]]);
    //         }
    //         puts(b->fns[col] + indices[nindices - 1] + 1);
    //     }
    // }
    // static void debug_print_board(princess *p) {
    //     fputs("\e[1;1H\e[2J", stdout); // clear screen

    //     if (p->options & DEBUG_PRINT_BOARD)
    //         print_board(&p->board, p->handmaidens, p->nhm);

    //     if (p->options & DEBUG_PRINT_STACKS)
    //         for (int i = 0; i < p->nhm; ++i) {
    //             printf("maiden %d: ", i);
    //             dump_value(a2v(p->handmaidens[i]->stack), stdout);
    //             putchar('\n');
    //         }
    // }

    // #ifdef PRINCESS_ISNT_WORKING_FOR_ME
    // #include <Windows.h>
    // static void sleep_for_ms(int ms){ Sleep(ms); }
    // #else
    // #include <time.h>
    // static void sleep_for_ms(int ms) {
    //     nanosleep(&(struct timespec) { 0, ms * 1000000 }, 0);
    // }
    // #endif
}
