const std = @import("std");
const utils = @import("utils.zig");
const Board = @import("Board.zig");
const Minotaur = @import("Minotaur.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Labyrinth = @This();

pub const MinotaurId = usize;

board: Board,
options: Options = .{},
minotaurs: std.ArrayListUnmanaged(Minotaur),
minotaursToSpawn: std.ArrayListUnmanaged(Minotaur),
allocator: Allocator,
exitStatus: ?u8 = null,
rng: std.rand.DefaultPrng,

pub const Options = struct {
    printBoard: bool = false,
    printMinotaurs: bool = false,
    waitForUserInput: bool = false,
    debug: bool = false,
    sleepMs: u32 = 25,
};

pub fn init(alloc: Allocator, board: Board, options: Options) Allocator.Error!Labyrinth {
    var minotaurs = try std.ArrayListUnmanaged(Minotaur).initCapacity(alloc, 8);
    errdefer minotaurs.deinit(alloc);

    var minotaursToSpawn = try std.ArrayListUnmanaged(Minotaur).initCapacity(alloc, 4);
    errdefer minotaursToSpawn.deinit(alloc);

    var minotaur = try Minotaur.initCapacity(alloc, 8);
    errdefer minotaur.deinit();
    try minotaurs.append(alloc, minotaur);

    return Labyrinth{
        .board = board,
        .allocator = alloc,
        .minotaurs = minotaurs,
        .options = options,
        .minotaursToSpawn = minotaursToSpawn,
        .rng = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())),
    };
}

pub fn deinit(this: *Labyrinth) void {
    this.board.deinit(this.allocator);

    for (this.minotaurs.items) |*minotaur| minotaur.deinit();
    this.minotaurs.deinit(this.allocator);

    for (this.minotaursToSpawn.items) |*minotaur| minotaur.deinit();
    this.minotaursToSpawn.deinit(this.allocator);
}

pub fn format(
    this: *const Labyrinth,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.writeAll("Labyrinth(");
    // if (this.options & 1 == 1) {
    //     try writer.writeAll("board=");
    //     try this.board.dump(writer);
    //     try writer.print(", options={d}, ", .{this.options});
    // }

    try writer.writeAll("minotaurs=[");
    for (this.minotaurs.items) |minotaur, idx| {
        if (idx != 0) try writer.writeAll(", ");
        try writer.print("{}", .{minotaur});
    }
    try writer.writeAll("])");
}

pub fn spawnMinotaur(this: *Labyrinth, minotaur: Minotaur) Allocator.Error!void {
    try this.minotaursToSpawn.append(this.allocator, minotaur);
}

pub fn slayMinotaur(this: *Labyrinth, id: MinotaurId) MinotaurGetError!void {
    if (this.minotaurs.items.len <= id) return error.MinotaurDoesntExist;

    const isLast = this.minotaurs.items.len == 1;
    var minotaur = if (isLast) this.minotaurs.pop() else this.minotaurs.swapRemove(id);
    if (isLast) this.exitStatus = minotaur.exitStatus;
    minotaur.deinit();
}

pub fn debugPrint(this: *const Labyrinth, writer: anytype) std.os.WriteError!void {
    std.time.sleep(this.options.sleepMs * 1_000_000);
    try utils.clearScreen(writer);
    try this.board.printBoard(this.minotaurs.items, writer);

    if (this.options.printMinotaurs) {
        try writer.writeAll("\n");
        for (this.minotaurs.items) |minotaur, i|
            try writer.print("minotaur {d}: {}\n", .{ i, minotaur });
    }
}

fn addNewMinotaurs(this: *Labyrinth) Allocator.Error!void {
    try this.minotaurs.appendSlice(this.allocator, this.minotaursToSpawn.items);
    this.minotaursToSpawn.clearRetainingCapacity();
}

fn debugPrintBoard(this: *const Labyrinth) !void {
    if (!this.options.printBoard) return;
    try this.debugPrint(std.io.getStdOut().writer());
    std.time.sleep(this.options.sleepMs * 1_000_000);
}

pub fn printBoard(this: *const Labyrinth, writer: anytype) !void {
    try this.board.printBoard(this.minotaurs.items, writer);
}

pub fn printMinotaurs(this: *const Labyrinth, writer: anytype) !void {
    for (this.minotaurs.items) |minotaur, i|
        try writer.print("minotaur {d}: {}\n", .{ i, minotaur });
}

fn isDone(this: *const Labyrinth) bool {
    return this.exitStatus != null;
}

pub const MinotaurGetError = error{MinotaurDoesntExist};
pub fn getMinotaur(this: *Labyrinth, id: MinotaurId) MinotaurGetError!*Minotaur {
    if (this.minotaurs.items.len <= id) return error.MinotaurDoesntExist;
    return &this.minotaurs.items[id];
}

// returns whether the minotaur is still alive.
pub fn stepMinotaur(this: *Labyrinth, id: MinotaurId) !bool {
    var minotaur = try this.getMinotaur(id);
    try minotaur.step(this);

    if (!minotaur.hasExited()) return true;
    this.slayMinotaur(id) catch unreachable;
    return false;
}

pub fn stepAllMinotaurs(this: *Labyrinth) !void {
    var idx: usize = 0;

    while (idx < this.minotaurs.items.len) {
        if (try this.stepMinotaur(idx)) idx += 1;
    }

    try this.addNewMinotaurs();
}

pub fn play(this: *Labyrinth) !void {
    try this.debugPrintBoard();

    // we have to go one back so we start at the origin.
    for (this.minotaurs.items) |*minotaur|
        minotaur.position = try minotaur.position.sub(minotaur.velocity);

    while (!this.isDone()) {
        try this.stepAllMinotaurs();
        try this.debugPrintBoard();
    }
}
