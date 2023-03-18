const std = @import("std");
const Labyrinth = @import("Labyrinth.zig");
const utils = @import("utils.zig");
const Debugger = @This();

labyrinth: *Labyrinth,
prevCommand: Command = Command.noop,

pub fn init(labyrinth: *Labyrinth) Debugger {
    return .{ .labyrinth = labyrinth };
}

pub fn run(this: Debugger) !void {
    var stdout = std.io.getStdOut().writer();
    var stdin = std.io.getStdIn().reader();
    var lineBuf: [2048]u8 = undefined;

    while (true) {
        try stdout.writeAll("> ");
        try stdout.sync();
        const line = stdin.readUntilDelimiter(lineBuf, '\n') catch |err| switch (err) {
            .StreamTooLong => {
                try stdout.print("input too large (cap={})\n", @typeInfo(@TypeOf(lineBuf)).Array.len);
                continue;
            },
            else => {
                try utils.eprintln("unable to read from stdin: {}; exiting", err);
                return;
            },
        };
        _ = line;
        _ = this;
        // var line = undefined;
        // _ = line;
        // const command = this.parseCommand() catch |err| {
        //     utils.eprintln("unable to parse command: {}", .{err});
        //     continue;
        // };
        // _ = command;
    }
}

const Command = union(enum) {
    const Names = enum { dump, jump };
    // Step: struct { which: usize,
    dump: ?usize,
    jump: struct { which: usize, to: @import("Coordinate.zig") },
    noop: void,

    pub const ParseError = error{ UnknownCommandName, TooFewArgs } || std.fmt.ParseIntError;

    fn read(comptime T: type, in: ?[]const u8) !T {
        _ = in;
        // return std.fmt.parseInt(usize, in orelse return error.TooFewArgs);
        return undefined;
    }

    fn parse(line: []const u8) ParseError!?Command {
        var tokens = std.mem.tokenize(u8, line, &std.ascii.whitespace);
        const cmd = tokens.next() orelse return null;

        switch (std.meta.stringToEnum(Names, cmd) orelse return error.UnknownCommandName) {
            .dump => {
                const which = if (tokens.next()) |arg| try std.fmt.parseInt(usize, arg, 10) else null;
                return Command{ .dump = which };
            },
            .jump => {
                const which = try read(usize, tokens.next());
                const x = try std.fmt.parseInt(i32, tokens.next() orelse return error.TooFewArgs, 10);
                const y = try std.fmt.parseInt(i32, tokens.next() orelse return error.TooFewArgs, 10);
                return .{ .jump = .{ .which = which, .to = .{ .x = x, .y = y } } };
            },
        }
    }

    pub fn run(this: Command, labyrinth: *Labyrinth) !void {
        switch (this) {
            .noop => {},
            .dump => |which| {
                if (which) |idx| {
                    const minotaur = utils.safeIndex(labyrinth.minotaurs.items, idx) orelse return error.IndexDoesntExist;
                    try utils.println("{}", .{minotaur});
                } else {
                    try utils.println("{}", .{labyrinth});
                }
            },
            .jump => |j| {
                var minotaur = utils.safeIndex(labyrinth.minotaurs.items, j.which) orelse return error.IndexDoesntExist;
                minotaur.position = j.to;
            },
        }
    }
};

pub fn takeInput(this: *Debugger, labyrinth: *Labyrinth) !void {
    const line = try utils.readLine(labyrinth.allocator, 1024);
    defer {
        if (line) |l| labyrinth.allocator.free(l);
    }

    const command = try Command.parse(line orelse "") orelse this.prevCommand;
    this.prevCommand = command;
    try command.run(labyrinth);
}
