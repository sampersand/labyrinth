const std = @import("std");
const Board = @import("Board.zig");
const Minotaur = @import("Minotaur.zig");
const assert = std.debug.assert;

const Labyrinth = @This();

board: Board,
options: i32 = 0,
minotaurs: std.ArrayList(Minotaur),
minotaursToSpawn: std.ArrayList(Minotaur),
rng: std.rand.DefaultPrng = std.rand.DefaultPrng.init(0x42),

pub fn init(board: Board, alloc: std.mem.Allocator) std.mem.Allocator.Error!Labyrinth {
    var minotaurs = try std.ArrayList(Minotaur).initCapacity(alloc, 8);
    errdefer minotaurs.deinit();

    var minotaursToSpawn = try std.ArrayList(Minotaur).initCapacity(alloc, 4);
    errdefer minotaursToSpawn.deinit();

    var minotaur = try Minotaur.initCapacity(alloc, 8);
    errdefer minotaur.deinit();

    try minotaurs.append(minotaur);
    return Labyrinth{ .board = board, .minotaurs = minotaurs, .minotaursToSpawn = minotaursToSpawn };
}

pub fn deinit(this: *Labyrinth) void {
    this.board.deinit();

    for (this.minotaurs.items) |*minotaur| {
        minotaur.deinit();
    }
    this.minotaurs.deinit();

    for (this.minotaursToSpawn.items) |*minotaur| {
        minotaur.deinit();
    }
    this.minotaursToSpawn.deinit();
}

pub fn format(
    this: *const Labyrinth,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    _ = fmt;
    _ = options;
    try writer.writeAll("Labyrinth(");
    if (this.options & 1 == 1) {
        try writer.writeAll("board=");
        try this.board.dump(writer);
        try writer.print(", options={d}, ", .{this.options});
    }

    try writer.writeAll("minotaurs=[");
    for (this.minotaurs.items) |minotaur, idx| {
        if (idx != 0) {
            try writer.writeAll(", ");
        }
        try writer.writeAll("\n\t");
        try minotaur.dump(writer);
    }
    try writer.print("\n])", .{});
}

pub fn spawnMinotaur(this: *Labyrinth, minotaur: Minotaur) std.mem.Allocator.Error!void {
    return this.minotaursToSpawn.append(minotaur);
}

pub fn slayMinotaur(this: *Labyrinth, idx: usize) void {
    assert(idx < this.minotaurs.items.len);
    var minotaur = this.minotaurs.swapRemove(idx);
    minotaur.deinit();
}

pub fn debugPrint(this: *const Labyrinth, writer: anytype) std.os.WriteError!void {
    try writer.writeAll("\x1B[1;1H\x1B[2J"); // clear screen
    try this.board.printBoard(this.minotaurs.items, writer);
    try writer.writeAll("\n");
    for (this.minotaurs.items) |minotaur, i| {
        try writer.print("minotaur {d}: {}\n", .{ i, minotaur });
    }
    std.time.sleep(sleepMs * 1_000_000);
}

fn shouldPrintDebug(_: *const Labyrinth) bool {
    return false;
}
const sleepMs = 25;

pub fn play(this: *Labyrinth) !i32 {
    for (this.minotaurs.items) |*minotaur| {
        minotaur.unstep();
    }

    while (true) : ({
        try this.minotaurs.appendSlice(this.minotaursToSpawn.items);
        this.minotaursToSpawn.clearRetainingCapacity();
        if (this.shouldPrintDebug()) {
            try this.debugPrint(std.io.getStdOut().writer());
        }
    }) {
        var idx: usize = 0;
        while (idx < this.minotaurs.items.len) {
            switch (try this.minotaurs.items[idx].play(this)) {
                .Continue => idx += 1,
                .Exit => |code| {
                    if (this.minotaurs.items.len == 1) {
                        if (this.shouldPrintDebug()) {
                            try this.debugPrint(std.io.getStdOut().writer());
                        }
                        return code;
                    }
                    this.slayMinotaur(idx);
                },
            }
        }
    }
}
