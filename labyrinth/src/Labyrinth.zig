const std = @import("std");
const utils = @import("utils.zig");
const Maze = @import("Maze.zig");
const Minotaur = @import("Minotaur.zig");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const Labyrinth = @This();

pub const MinotaurId = usize;

maze: Maze,
options: Options = .{},
minotaurs: std.ArrayListUnmanaged(*Minotaur),
allocator: Allocator,
exit_status: ?u8 = null,
generation: usize = 0,
stdout: std.fs.File,
spawned_count: usize = 0,
rng: std.rand.DefaultPrng,

pub const Options = struct {
    print_maze: bool = false,
    print_minotaurs: bool = false,
    wait_for_user_input: bool = false,
    debug: bool = false,
    sleep_ms: u32 = 10, //25,
};

pub fn init(alloc: Allocator, maze: Maze, options: Options) Allocator.Error!Labyrinth {
    var minotaurs = try std.ArrayListUnmanaged(*Minotaur).initCapacity(alloc, 8);
    errdefer minotaurs.deinit(alloc);

    var minotaur = try Minotaur.initCapacity(alloc, 8);
    minotaur.is_first = true;
    errdefer minotaur.deinit();
    try minotaurs.append(alloc, minotaur);

    return Labyrinth{
        .maze = maze,
        .allocator = alloc,
        .minotaurs = minotaurs,
        .options = options,
        .stdout = std.io.getStdOut(),
        .rng = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())),
    };
}

pub fn deinit(labyrinth: *Labyrinth) void {
    labyrinth.maze.deinit(labyrinth.allocator);

    for (labyrinth.minotaurs.items) |minotaur|
        minotaur.deinit();

    labyrinth.minotaurs.deinit(labyrinth.allocator);
}

pub fn format(
    this: *const Labyrinth,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.writeAll("Labyrinth(");
    // if (this.options & 1 == 1) {
    //     try writer.writeAll("maze=");
    //     try this.maze.dump(writer);
    //     try writer.print(", options={d}, ", .{this.options});
    // }

    try writer.writeAll("minotaurs=[");
    for (this.minotaurs.items) |minotaur, idx| {
        if (idx != 0) try writer.writeAll(", ");
        try writer.print("{}", .{minotaur});
    }
    try writer.writeAll("])");
}

pub fn spawnMinotaur(this: *Labyrinth, minotaur: *Minotaur) Allocator.Error!void {
    try this.minotaurs.append(this.allocator, minotaur);
    this.spawned_count += 1;
}

pub fn slayMinotaur(this: *Labyrinth, id: MinotaurId) MinotaurGetError!void {
    if (this.minotaurs.items.len <= id) return error.MinotaurDoesntExist;

    const is_last = this.minotaurs.items.len == 1;
    var minotaur = if (is_last) this.minotaurs.pop() else this.minotaurs.swapRemove(id);
    if (is_last) this.exit_status = minotaur.exit_status;
    minotaur.deinit();
}

pub fn debugPrint(this: *const Labyrinth, writer: anytype) std.os.WriteError!void {
    std.time.sleep(this.options.sleep_ms * 1_000_000);
    try utils.clearScreen(writer);
    try writer.print("tick {d}\n", .{this.generation});
    try this.maze.printMaze(this.minotaurs.items, writer);

    if (this.options.print_minotaurs) {
        try writer.writeAll("\n");
        for (this.minotaurs.items) |minotaur, i|
            try writer.print("minotaur {d}: {}\n", .{ i, minotaur });
    }
}

fn addNewMinotaurs(this: *Labyrinth) Allocator.Error!bool {
    defer this.spawned_count = 0;
    return this.spawned_count != 0;
}

fn debugPrintMaze(this: *const Labyrinth) !void {
    if (!this.options.print_maze) return;
    try this.debugPrint(std.io.getStdOut().writer());
    std.time.sleep(this.options.sleep_ms * 1_000_000);
}

pub fn printMaze(this: *const Labyrinth, writer: anytype) !void {
    try this.maze.printMaze(this.minotaurs.items, writer);
}

pub fn printMinotaurs(this: *const Labyrinth, writer: anytype) !void {
    for (this.minotaurs.items) |minotaur, i|
        try writer.print("minotaur {d}: {}\n", .{ i, minotaur });
}

pub fn isDone(this: *const Labyrinth) bool {
    return this.exit_status != null;
}

pub const MinotaurGetError = error{MinotaurDoesntExist};
pub fn getMinotaur(this: *Labyrinth, id: MinotaurId) MinotaurGetError!*Minotaur {
    if (this.minotaurs.items.len <= id) return error.MinotaurDoesntExist;
    return this.minotaurs.items[id];
}

// returns whether the minotaur is still alive.
pub const TickResult = enum { slayed, spawned, alive };
pub fn tickMinotaur(this: *Labyrinth, id: MinotaurId) !TickResult {
    var minotaur = try this.getMinotaur(id);
    try minotaur.tick(this);

    if (!minotaur.hasExited()) {
        return if (try this.addNewMinotaurs()) .spawned else .alive;
    }

    this.slayMinotaur(id) catch unreachable; // we already validated it earlier.
    const new_spawned = try this.addNewMinotaurs();
    assert(!new_spawned); // we dont (currently) spawn minotaurs at the same time we slay them.
    return .slayed;
}

pub fn stepAllMinotaurs(this: *Labyrinth) !void {
    var minotaur_id: usize = 0;
    var amnt_to_step = this.minotaurs.items.len;
    var amnt_of_spawned_minotaurs: usize = 0;

    this.generation += 1;
    // We have to be careful to not tick new minotaurs that have been added by previous minotaurs
    // during this stepping process. Since Labyrinth makes no gaurantees about the execution order
    // of minotaurs, we slay minotaurs by replacing them with the lastmost in the list (so we dont
    // have to shift everything over each time). However, this means that we might have swapped
    // a new minotaur over. We make sure we don't do this by keeping track of how many new minotaurs
    // have spawned: If at least one is around, then we skip it and tick the next one.
    while (minotaur_id < amnt_to_step) {
        switch (try this.tickMinotaur(minotaur_id)) {
            // If the minotaur is still alive, then just advance.
            .alive => minotaur_id += 1,

            // A new one was spawned, so we advance and incrmement the spawned count.
            .spawned => {
                minotaur_id += 1;
                amnt_of_spawned_minotaurs += 1;
            },

            // The slain minotaur has been swapped with the last minotaur. So if that's
            // a new minotaur, we skip over it, and decrement the amount of new minotaurs.
            .slayed => if (amnt_of_spawned_minotaurs == 0) {
                amnt_to_step -= 1;
            } else {
                // otherwise, we just swapped in a new minotaur, so we decrement the spawned count.
                minotaur_id += 1;
                amnt_of_spawned_minotaurs -= 1;
            },
        }
    }
}

pub fn play(this: *Labyrinth) !void {
    try this.debugPrintMaze();

    while (!this.isDone()) {
        try this.stepAllMinotaurs();
        try this.debugPrintMaze();
    }
}
