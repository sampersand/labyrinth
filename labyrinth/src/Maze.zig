const std = @import("std");
const Allocator = std.mem.Allocator;
const Function = @import("function.zig").Function;
const Minotaur = @import("Minotaur.zig");
const Coordinate = @import("Coordinate.zig");
const utils = @import("utils.zig");
const Maze = @This();

// Note that on the maze, `(0,0)` is the upper left; `y` is the line and `x` is the col.
filename: []const u8,
lines: std.ArrayListUnmanaged([]u8),
max_x: usize = 0,

fn parseMaze(maze: *Maze, alloc: Allocator, source: []const u8) Allocator.Error!void {
    var iter = std.mem.split(u8, source, "\n");

    // Ignore shebang if it exists.
    if (2 <= source.len and source[0] == '#' and source[1] == '!') {
        _ = iter.next();
    }

    while (iter.next()) |line| {
        var dup = try alloc.dupe(u8, line);
        errdefer alloc.free(dup);

        if (line.len > maze.max_x) maze.max_x = line.len;
        try maze.lines.append(alloc, @ptrCast([]u8, dup));
    }
}

pub fn init(alloc: Allocator, filename: []const u8, source: []const u8) Allocator.Error!Maze {
    var maze = Maze{
        .filename = filename,
        .lines = try std.ArrayListUnmanaged([]u8).initCapacity(alloc, 8),
    };
    errdefer maze.deinit(alloc);

    try maze.parseMaze(alloc, source);
    return maze;
}

pub fn deinit(maze: *Maze, alloc: Allocator) void {
    for (maze.lines.items) |line|
        alloc.free(line);
    maze.lines.deinit(alloc);
}

pub fn get(maze: *const Maze, pos: Coordinate) ?u8 {
    const line = utils.safeIndex(maze.lines.items, @as(usize, pos.y)) orelse return null;
    return utils.safeIndex(line, @as(usize, pos.x));
}

fn printXHeadings(writer: anytype, max_x: usize, max_y_len: usize) std.os.WriteError!void {
    var range = std.math.log10(max_x) + 1;

    while (range != 0) : (range -= 1) {
        const repeat_amount = std.math.pow(usize, 10, range - 1);
        try writer.writeByteNTimes(' ', max_y_len + repeat_amount);
        var x: u8 = 1;
        while (x <= @divTrunc(max_x, repeat_amount)) : (x += 1) {
            try writer.writeByteNTimes('0' + (x % 10), std.math.min(
                max_x - repeat_amount * x + 1,
                repeat_amount,
            ));
        }
        try writer.writeByte('\n');
    }
}

pub fn printMaze(maze: *const Maze, minotaurs: []*Minotaur, writer: anytype) std.os.WriteError!void {
    const Cursor = struct {
        idx: usize,
        id: usize,
        age: usize,
        fn cmp(_: void, l: @This(), r: @This()) bool {
            return l.idx < r.idx;
        }
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var indices = std.ArrayList(Cursor).initCapacity(allocator, minotaurs.len) catch @panic("oops?");

    try writer.print("file: {s}\n", .{maze.filename});

    const max_y_len = std.math.log10(maze.lines.items.len) + 1;
    try printXHeadings(writer, maze.max_x, max_y_len);

    for (maze.lines.items) |line, col| {
        indices.clearRetainingCapacity();

        for (minotaurs) |minotaur| {
            for (minotaur.positions) |pos, i|
                if (pos.y == col and pos.x >= 0)
                    indices.append(.{
                        .idx = @intCast(usize, pos.x),
                        .age = i,
                        .id = minotaur.colour,
                    }) catch unreachable;
        }

        try writer.print("{[c]d: >[l]} ", .{ .c = col, .l = max_y_len });
        if (indices.items.len == 0) {
            try writer.print("{s}\n", .{line});
            continue;
        }

        std.sort.sort(Cursor, indices.items, {}, Cursor.cmp);
        var i: usize = 0;
        while (i < indices.items.len) : (i += 1) {
            const index = indices.items[i];
            if (i != 0 and index.idx == indices.items[i - 1].idx)
                continue;

            const start = if (i == 0) 0 else indices.items[i - 1].idx + 1;
            const len = index.idx - start;
            try writer.print("{s}\x1B[48;5;{}m{c}\x1B[0m", .{
                line[start .. start + len],
                ((index.id + 16) % 36) + 36 * (6 - index.age),
                line[index.idx],
            });
        }

        try writer.print("{s}\n", .{line[indices.items[indices.items.len - 1].idx + 1 ..]});
    }
}
