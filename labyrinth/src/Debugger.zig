const std = @import("std");
const Labyrinth = @import("Labyrinth.zig");
const utils = @import("utils.zig");
const Debugger = @This();

labyrinth: *Labyrinth,
command: Command = Command.noop,

pub fn init(labyrinth: *Labyrinth) Debugger {
    return .{ .labyrinth = labyrinth };
}

pub fn run(this: *Debugger) !void {
    const stdout = std.io.getStdOut().writer();
    var stdin = std.io.getStdIn().reader();
    var lineBuf: [2048]u8 = undefined;

    while (true) {
        try stdout.writeAll("> ");
        try std.io.getStdOut().sync();

        const line = stdin.readUntilDelimiter(&lineBuf, '\n') catch |err| switch (err) {
            error.StreamTooLong => {
                try stdout.print("input too large (cap={d})\n", .{@typeInfo(@TypeOf(lineBuf)).Array.len});
                continue;
            },
            else => {
                try utils.eprintln("unable to read from stdin: {}; exiting", .{err});
                return;
            },
        };

        var context: Command.ParseContext = undefined;
        _ = b: {
            if (Command.parse(line, &context) catch |e| break :b e) |cmd| this.command = cmd;
            if (this.command == Command.quit) break;
            break :b this.command.run(this);
        } catch {
            try utils.eprintln("{}", .{context});
        };
    }
}

const Command = union(enum) {
    pub const ParseError = error{ UnknownCommandName, TooFewArgs, CantParseInt };
    pub const ParseContext = union(enum) {
        UnknownCommandName: []const u8,
        TooFewArgs: []const u8,
        CantParseInt: std.fmt.ParseIntError,

        fn fail(this: *@This(), comptime err: ParseError, value: anytype) ParseError {
            this.* = @unionInit(@This(), std.meta.tagName(err), value);
            return err;
        }
    };

    // zig fmt: off
    const Names = enum {
        dump, d,
        jump, j,
        quit, q,
        step, s,
        stepm, sm,
        help,
        @"print-board", pr,
    };
    // zig fmt: on

    dumpAll: void,
    dumpMinotaur: usize,
    jump: struct { which: usize, to: @import("Coordinate.zig") },
    stepAll: usize,
    stepOne: struct { minotaur: usize, amount: usize },
    noop: void,
    help: void,
    quit: void,
    print: struct { board: bool, minotaurs: bool },

    fn read(comptime T: type, in: []const u8, ctx: *ParseContext) ParseError!T {
        return std.fmt.parseInt(T, in, 10) catch |err| ctx.fail(error.CantParseInt, err);
    }

    fn parse(line: []const u8, ctx: *ParseContext) ParseError!?Command {
        var tokens = std.mem.tokenize(u8, line, &std.ascii.whitespace);
        const cmdName = tokens.next() orelse return null;

        const cmd = std.meta.stringToEnum(Names, cmdName) orelse
            return ctx.fail(error.UnknownCommandName, cmdName);

        return switch (cmd) {
            .dump, .d => if (tokens.next()) |arg| .{ .dumpMinotaur = try read(usize, arg, ctx) } else .dumpAll,
            .quit, .q => .quit,
            .step, .s => .{ .stepAll = if (tokens.next()) |arg| try read(usize, arg, ctx) else 1 },
            .stepm, .sm => .{ .stepOne = .{
                .minotaur = try read(usize, tokens.next() orelse return ctx.fail(error.TooFewArgs, cmdName), ctx),
                .amount = if (tokens.next()) |arg| try read(usize, arg, ctx) else 1,
            } },
            .jump, .j => {
                return null;
                // const which = try read(usize, tokens.next());
                // const x = try std.fmt.parseInt(i32, tokens.next() orelse return error.TooFewArgs, 10);
                // const y = try std.fmt.parseInt(i32, tokens.next() orelse return error.TooFewArgs, 10);
                // return .{ .jump = .{ .which = which, .to = .{ .x = x, .y = y } } };
            },
            .help => .help,
            .@"print-board", .pr => .{ .print = .{ .board = true, .minotaurs = true } },
        };
    }

    pub fn run(this: Command, debugger: *Debugger) !void {
        switch (this) {
            .noop => {},
            .dumpMinotaur => {},
            .dumpAll => try utils.println("{}", .{debugger.labyrinth}),
            .jump => {},
            .help => {},
            .stepOne => {},
            .stepAll => |amnt| {
                var n = @as(usize, 0);
                while (n < amnt) : (n += 1) {
                    try debugger.labyrinth.stepAllMinotaurs();
                }
            },
            .print => |info| {
                const stdout = std.io.getStdOut().writer();
                if (info.board) {
                    try debugger.labyrinth.printBoard(stdout);
                    if (info.minotaurs) try stdout.writeByte('\n');
                }
                if (info.minotaurs) try debugger.labyrinth.printMinotaurs(stdout);
            },
            .quit => unreachable, // should be handled in minotaur
            // .dump => |which| {
            //     if (which) |idx| {
            //         const minotaur = utils.safeIndex(labyrinth.minotaurs.items, idx) orelse return error.IndexDoesntExist;
            //         try utils.println("{}", .{minotaur});
            //     } else {
            //         try utils.println("{}", .{labyrinth});
            //     }
            // },
            // .jump => |j| {
            //     var minotaur = utils.safeIndex(labyrinth.minotaurs.items, j.which) orelse return error.IndexDoesntExist;
            //     minotaur.position = j.to;
            // },
        }
    }
};

//     fn read(comptime T: type, in: ?[]const u8) !T {
//         _ = in;
//         // return std.fmt.parseInt(usize, in orelse return error.TooFewArgs);
//         return undefined;
//     }

// pub fn takeInput(this: *Debugger, labyrinth: *Labyrinth) !void {
//     const line = try utils.readLine(labyrinth.allocator, 1024);
//     defer {
//         if (line) |l| labyrinth.allocator.free(l);
//     }

//     const command = try Command.parse(line orelse "") orelse this.prevCommand;
//     this.prevCommand = command;
//     try command.run(labyrinth);
// }
