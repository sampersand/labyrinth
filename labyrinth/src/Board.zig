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
    for (this.lines.items) |line|
        this.lines.allocator.free(line);

    this.lines.deinit();
}

pub const GetError = error{IntOutOfBounds};
pub fn get(this: *const Board, pos: Coordinate) GetError!u8 {
    // std.debug.print("{d}|{d}\n", pos);
    const y = std.math.cast(usize, pos.y) orelse return error.IntOutOfBounds;
    const x = std.math.cast(usize, pos.x) orelse return error.IntOutOfBounds;

    if (this.lines.items.len <= y)
        return error.IntOutOfBounds;

    const line = this.lines.items[y];
    if (line.len <= x)
        return error.IntOutOfBounds;

    return line[x];
}

pub fn printBoard(this: *const Board, minotaurs: []Minotaur, writer: anytype) std.os.WriteError!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var indices = std.ArrayList(usize).initCapacity(allocator, minotaurs.len) catch @panic("oops?");

    for (this.lines.items) |line, col| {
        indices.clearRetainingCapacity();

        for (minotaurs) |minotaur| {
            if (minotaur.position.y == col)
                indices.append(@intCast(usize, minotaur.position.x)) catch unreachable;
        }

        if (indices.items.len == 0) {
            try writer.print("{s}\n", .{line});
            continue;
        }

        std.sort.sort(usize, indices.items, {}, std.sort.asc(usize));
        var i: usize = 0;
        while (i < indices.items.len) : (i += 1) {
            if (i != 0 and indices.items[i] == indices.items[i - 1])
                continue;

            const start = if (i == 0) 0 else indices.items[i - 1] + 1;

            const len = indices.items[i] - start;
            try writer.print(
                "{s}\x1B[7m{c}\x1B[0m",
                .{ line[start .. start + len], line[indices.items[i]] },
            );
        }

        try writer.print("{s}\n", .{line[indices.items[indices.items.len - 1] + 1 ..]});
    }
}
