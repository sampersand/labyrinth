const std = @import("std");
const utils = @import("utils.zig");
const Debugger = @import("Debugger.zig");
const Board = @import("Board.zig");
const Minotaur = @import("Minotaur.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Labyrinth = @This();

board: Board,
options: Options = .{},
minotaurs: std.ArrayListUnmanaged(Minotaur),
minotaursToSpawn: std.ArrayListUnmanaged(Minotaur),
allocator: Allocator,
exitStatus: ?i32 = null,
debugger: Debugger,
rng: std.rand.DefaultPrng,

pub const Options = struct {
    printBoard: bool = false,
    printMinotaurs: bool = false,
    waitForUserInput: bool = false,
    sleepMs: u32 = 25,
};

pub fn init(board: Board, alloc: Allocator) Allocator.Error!Labyrinth {
    var minotaurs = try std.ArrayListUnmanaged(Minotaur).initCapacity(alloc, 8);
    errdefer minotaurs.deinit(alloc);

    var minotaursToSpawn = try std.ArrayListUnmanaged(Minotaur).initCapacity(alloc, 4);
    errdefer minotaursToSpawn.deinit(alloc);

    var minotaur = try Minotaur.initCapacity(alloc, 8);
    errdefer minotaur.deinit();
    try minotaurs.append(alloc, minotaur);

    return Labyrinth{
        .board = board,
        .debugger = .{},
        .allocator = alloc,
        .minotaurs = minotaurs,
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

pub fn slayMinotaur(this: *Labyrinth, idx: usize) void {
    assert(idx < this.minotaurs.items.len);

    const isLast = this.minotaurs.items.len == 1;
    var minotaur = if (isLast) this.minotaurs.pop() else this.minotaurs.swapRemove(idx);
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

fn isDone(this: *const Labyrinth) bool {
    return this.exitStatus != null;
}

fn stepAllMinotaurs(this: *Labyrinth) !void {
    var idx: usize = 0;
    while (idx < this.minotaurs.items.len) {
        var minotaur = &this.minotaurs.items[idx];
        try minotaur.play(this);

        if (minotaur.hasExited()) {
            this.slayMinotaur(idx);
        } else {
            idx += 1;
        }
    }
}

pub fn play(this: *Labyrinth) !void {
    try this.debugPrintBoard();

    // we have to go one back so we start at the origin.
    for (this.minotaurs.items) |*minotaur|
        minotaur.position = minotaur.position.sub(minotaur.velocity);

    while (!this.isDone()) {
        try this.stepAllMinotaurs();
        try this.addNewMinotaurs();
        try this.debugPrintBoard();
    }
}

pub fn triggerError(this: *Labyrinth, err: anytype, context: anytype) @TypeOf(err) {
    std.log.err("error: {} (context: {})", .{ err, context });
    this.debugger.takeInput(this) catch @panic("unable to do debugger"); //: {}", null, .{e});
    return err;
}
