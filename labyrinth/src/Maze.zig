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

pub fn init(alloc: Allocator, filename: []const u8, source: []const u8) Allocator.Error!Maze {
    var maze = Maze{
        .filename = filename,
        .lines = try std.ArrayListUnmanaged([]u8).initCapacity(alloc, 8),
    };
    errdefer maze.deinit(alloc);

    var line_iter = std.mem.split(u8, source, "\n");
    while (line_iter.next()) |line| {
        var dup = try alloc.dupe(u8, line);
        errdefer alloc.free(dup);

        maze.max_x = std.math.max(dup.len, maze.max_x);
        try maze.lines.append(alloc, @ptrCast([]u8, dup));
    }

    return maze;
}

pub fn deinit(maze: *Maze, alloc: Allocator) void {
    for (maze.lines.items) |line| alloc.free(line);
    maze.lines.deinit(alloc);
}

pub fn get(maze: *const Maze, pos: Coordinate) ?u8 {
    return utils.safeIndex(utils.safeIndex(maze.lines.items, pos.y) orelse return null, pos.x);
}

pub fn set(maze: *Maze, alloc: Allocator, pos: Coordinate, val: u8) Allocator.Error!void {
    // Add more lines if needed
    if (maze.lines.items.len <= pos.y) {
        var to_alloc = pos.y - maze.lines.items.len + 1;
        try maze.lines.ensureTotalCapacity(alloc, @as(usize, pos.y));

        while (to_alloc != 0) : (to_alloc -= 1) {
            const line = alloc.alloc(u8, 0) catch unreachable; // alloc 0 never fails
            maze.lines.append(alloc, line) catch unreachable; // we ensured we had enough capacity.
        }
    }

    const line = &maze.lines.items[pos.y];

    // Resize line if needed.
    if (line.len <= pos.x) {
        const size = line.len;
        line.* = try alloc.realloc(line.*, pos.x + 1);
        std.mem.set(u8, line.*[size..], '\x00');
    }

    line.*[pos.x] = val;
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

pub const PrintOptions = struct {
    minotaurs: []*const Minotaur = &.{},
    filename: bool = true,
    axes: bool = true,
    tails: bool = true,
};

pub fn printMaze(maze: *const Maze, opts: PrintOptions, writer: anytype) std.os.WriteError!void {
    const Cursor = struct {
        idx: usize,
        id: usize,
        age: usize,
        pub fn colour(cursor: @This()) u8 {
            return @truncate(u8, (cursor.id % 36)) + 16 + 36 * (5 - @truncate(u8, cursor.age));
        }

        fn cmp(_: void, l: @This(), r: @This()) bool {
            return l.idx < r.idx;
        }
    };

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var indices = std.ArrayList(Cursor).initCapacity(arena.allocator(), opts.minotaurs.len) catch @panic("oops?");

    if (opts.filename) {
        try writer.print("file: {s}\n", .{maze.filename});
    }

    var max_y_len: usize = undefined;

    if (opts.axes) {
        max_y_len = std.math.log10(maze.lines.items.len) + 1;
        try printXHeadings(writer, maze.max_x, max_y_len);
    }

    for (maze.lines.items) |line, col| {
        indices.clearRetainingCapacity();

        for (opts.minotaurs) |minotaur| {
            for (minotaur.positions) |pos, i| {
                if (1 <= i and !opts.tails) break;
                if (pos.y != col) continue;

                indices.append(.{
                    .idx = @intCast(usize, pos.x),
                    .age = i,
                    .id = minotaur.colour,
                }) catch unreachable;
            }
        }

        if (opts.axes) {
            try writer.print("{[c]d: >[l]} ", .{ .c = col, .l = max_y_len });
        }

        if (indices.items.len == 0) {
            try writer.print("{s}\n", .{line});
            continue;
        }

        std.sort.sort(Cursor, indices.items, {}, Cursor.cmp);
        for (utils.range(indices.items.len)) |_, i| {
            const index = indices.items[i];
            if (i != 0 and index.idx == indices.items[i - 1].idx)
                continue;

            const start = if (i == 0) 0 else indices.items[i - 1].idx + 1;
            try writer.print(
                "{s}\x1B[48;5;{}m{c}\x1B[0m",
                .{ line[start..index.idx], index.colour(), line[index.idx] },
            );
        }

        try writer.print("{s}\n", .{line[indices.items[indices.items.len - 1].idx + 1 ..]});
    }
}

// TESTING THINGS
fn c(y: anytype, x: anytype) Coordinate {
    return .{ .x = x, .y = y };
}

fn expectGet(maze: *const Maze, expected: ?u8, coord: Coordinate) !void {
    return std.testing.expectEqual(expected, maze.get(coord));
}

test "init works with an empty source" {
    var maze = try Maze.init(std.testing.allocator, "", "");
    defer maze.deinit(std.testing.allocator);

    // Make sure `0,0` doesnt exist.
    try expectGet(&maze, null, c(0, 0));
}

test "get works." {
    var maze = try Maze.init(std.testing.allocator, "", "12\n345");
    defer maze.deinit(std.testing.allocator);

    try expectGet(&maze, '1', c(0, 0));
    try expectGet(&maze, '2', c(0, 1));
    try expectGet(&maze, null, c(0, 2));
    try expectGet(&maze, null, c(0, 3));

    try expectGet(&maze, '3', c(1, 0));
    try expectGet(&maze, '4', c(1, 1));
    try expectGet(&maze, '5', c(1, 2));
    try expectGet(&maze, null, c(1, 3));

    try expectGet(&maze, null, c(2, 0));
    try expectGet(&maze, null, c(2, 1));
    try expectGet(&maze, null, c(2, 2));
    try expectGet(&maze, null, c(2, 3));
}

test "set in bounds works." {
    var maze = try Maze.init(std.testing.allocator, "", "12\n345");
    defer maze.deinit(std.testing.allocator);

    try maze.set(std.testing.allocator, c(0, 0), 'A');
    try maze.set(std.testing.allocator, c(0, 1), 'B');
    try maze.set(std.testing.allocator, c(1, 0), 'C');
    try maze.set(std.testing.allocator, c(1, 1), 'D');
    try maze.set(std.testing.allocator, c(1, 2), 'E');

    try expectGet(&maze, 'A', c(0, 0));
    try expectGet(&maze, 'B', c(0, 1));
    try expectGet(&maze, 'C', c(1, 0));
    try expectGet(&maze, 'D', c(1, 1));
    try expectGet(&maze, 'E', c(1, 2));
}

test "set out of bounds works." {
    var maze = try Maze.init(std.testing.allocator, "", "12\n345");
    defer maze.deinit(std.testing.allocator);

    try maze.set(std.testing.allocator, c(0, 2), 'A');
    try maze.set(std.testing.allocator, c(1, 3), 'B');
    try maze.set(std.testing.allocator, c(2, 1), 'C');
    try maze.set(std.testing.allocator, c(9, 4), 'D');

    try expectGet(&maze, 'A', c(0, 2));
    try expectGet(&maze, 'B', c(1, 3));
    try expectGet(&maze, 'C', c(2, 1));
    try expectGet(&maze, 'D', c(9, 4));
    try expectGet(&maze, '\x00', c(9, 3)); // filler is null byte
    try expectGet(&maze, null, c(6, 0)); // unspecified lines are null.
}

// No testing the print because that's a huge pain.
