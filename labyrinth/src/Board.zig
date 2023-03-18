const std = @import("std");
const Allocator = std.mem.Allocator;
const Function = @import("function.zig").Function;
const Minotaur = @import("Minotaur.zig");
const Coordinate = @import("Coordinate.zig");
const utils = @import("utils.zig");
const Board = @This();

filename: []const u8,
lines: std.ArrayListUnmanaged([]u8),

fn parseBoard(board: *Board, alloc: Allocator, source: []const u8) Allocator.Error!void {
    var iter = std.mem.split(u8, source, "\n");
    while (iter.next()) |line| {
        var dup = try alloc.dupe(u8, line);
        errdefer alloc.free(dup);

        try board.lines.append(alloc, @ptrCast([]u8, dup));
    }
}

pub fn init(alloc: Allocator, filename: []const u8, source: []const u8) Allocator.Error!Board {
    var board = Board{
        .filename = filename,
        .lines = try std.ArrayListUnmanaged([]u8).initCapacity(alloc, 8),
    };
    errdefer board.deinit(alloc);

    try board.parseBoard(alloc, source);
    return board;
}

pub fn deinit(this: *Board, alloc: Allocator) void {
    for (this.lines.items) |line| alloc.free(line);
    this.lines.deinit(alloc);
}

pub const GetError = error{OutOfBounds};
pub fn get(this: *const Board, pos: Coordinate) GetError!u8 {
    const line = utils.safeIndex(this.lines.items, @as(usize, pos.y)) orelse return error.OutOfBounds;
    return utils.safeIndex(line, @as(usize, pos.x)) orelse return error.OutOfBounds;
}

pub fn printBoard(this: *const Board, minotaurs: []Minotaur, writer: anytype) std.os.WriteError!void {
    const Cursor = struct {
        idx: usize,
        age: usize,
        fn cmp(_: void, l: @This(), r: @This()) bool {
            return l.idx < r.idx;
        }
    };
    const colors = [4]usize{ 254, 248, 242, 236 };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var indices = std.ArrayList(Cursor).initCapacity(allocator, minotaurs.len) catch @panic("oops?");

    try writer.print("file: {s}\n", .{this.filename});
    for (this.lines.items) |line, col| {
        indices.clearRetainingCapacity();

        for (minotaurs) |minotaur| {
            if (minotaur.position.y == col)
                indices.append(.{ .idx = @intCast(usize, minotaur.position.x), .age = 0 }) catch unreachable;
            for (minotaur.prevPositions) |pos, i|
                if (pos.y == col and pos.x >= 0)
                    indices.append(.{ .idx = @intCast(usize, pos.x), .age = i + 1 }) catch unreachable;
        }

        if (indices.items.len == 0) {
            try writer.print("{s}\n", .{line});
            continue;
        }

        std.sort.sort(Cursor, indices.items, {}, Cursor.cmp);
        var i: usize = 0;
        while (i < indices.items.len) : (i += 1) {
            if (i != 0 and indices.items[i].idx == indices.items[i - 1].idx)
                continue;

            const start = if (i == 0) 0 else indices.items[i - 1].idx + 1;
            const len = indices.items[i].idx - start;
            try writer.print("{s}\x1B[48;5;{}m{c}\x1B[0m", .{
                line[start .. start + len],
                colors[indices.items[i].age],
                line[indices.items[i].idx],
            });
        }

        try writer.print("{s}\n", .{line[indices.items[indices.items.len - 1].idx + 1 ..]});
    }
}
