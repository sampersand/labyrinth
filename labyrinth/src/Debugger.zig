const std = @import("std");
const Labyrinth = @import("Labyrinth.zig");
const MinotaurId = Labyrinth.MinotaurId;
const utils = @import("utils.zig");
const Debugger = @This();
const Coordinate = @import("Coordinate.zig");
const Vector = @import("Vector.zig");

labyrinth: *Labyrinth,
command: Command = Command.noop,

pub fn init(labyrinth: *Labyrinth) Debugger {
    return .{ .labyrinth = labyrinth };
}

pub fn run(this: *Debugger) !void {
    const stdout = std.io.getStdOut().writer();
    var stdin = std.io.getStdIn().reader();
    var line_buf: [2048]u8 = undefined;

    while (true) {
        try stdout.writeAll("> ");
        try std.io.getStdOut().sync();

        const line = stdin.readUntilDelimiter(&line_buf, '\n') catch |err| switch (err) {
            error.StreamTooLong => {
                try stdout.print("input too large (cap={d})\n", .{@typeInfo(@TypeOf(line_buf)).Array.len});
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
    const ArgParser = struct {
        iter: std.mem.TokenIterator(u8),
        ctx: *ParseContext,
        cmd_name: []const u8,

        fn init(line: []const u8, ctx: *ParseContext) ?ArgParser {
            var iter = std.mem.tokenize(u8, line, &std.ascii.whitespace);
            const cmd_name = iter.next() orelse return null;
            return .{ .ctx = ctx, .iter = iter, .cmd_name = cmd_name };
        }

        fn next(this: *ArgParser) ?[]const u8 {
            return this.iter.next();
        }

        fn nextReq(this: *ArgParser) ParseError![]const u8 {
            return this.next() orelse return this.ctx.fail(error.TooFewArgs, this.cmd_name);
        }

        fn read(this: *ArgParser, comptime T: type) ParseError!T {
            return Command.read(T, try this.nextReq(), this.ctx);
        }

        fn readOr(this: *ArgParser, comptime T: type, default: T) ParseError!T {
            return if (this.next()) |arg|
                std.fmt.parseInt(T, arg, 10) catch |err| this.ctx.fail(error.CantParseInt, err)
            else
                default;
        }
    };

    fn read(comptime T: type, arg: []const u8, ctx: *ParseContext) ParseError!T {
        return std.fmt.parseInt(T, arg, 10) catch |err| ctx.fail(error.CantParseInt, err);
    }

    // zig fmt: off
    const Names = enum {
        dump, d,
        jump, j,
        @"set-position",
        @"set-velocity",
        quit, q,
        step, s,
        stepm, sm,
        help,
        @"print-board", pr,
    };
    // zig fmt: on

    dump_all: void,
    dump_minotaur: MinotaurId,
    jump_to: struct { id: MinotaurId, position: ?Coordinate = null, velocity: ?Vector = null },
    step_all: MinotaurId,
    step_one: struct { minotaur: MinotaurId, amount: usize },
    noop: void,
    help: void,
    quit: void,
    print: struct { board: bool, minotaurs: bool },

    fn parse(line: []const u8, ctx: *ParseContext) ParseError!?Command {
        var args = ArgParser.init(line, ctx) orelse return null;

        const cmd = std.meta.stringToEnum(Names, args.cmd_name) orelse
            return ctx.fail(error.UnknownCommandName, args.cmd_name);

        return switch (cmd) {
            .dump, .d => if (args.next()) |arg| .{ .dump_minotaur = try read(usize, arg, ctx) } else .dump_all,
            .quit, .q => .quit,
            .step, .s => .{ .step_all = try args.readOr(usize, 1) },
            .stepm, .sm => .{ .step_one = .{
                .minotaur = try args.read(usize),
                .amount = try args.readOr(usize, 1),
            } },
            .jump, .j => .{ .jump_to = .{
                .id = try args.read(usize),
                .position = .{ .x = try args.read(u32), .y = try args.read(u32) },
                .velocity = .{ .x = try args.read(i32), .y = try args.read(i32) },
            } },
            .@"set-position" => .{ .jump_to = .{
                .id = try args.read(usize),
                .position = .{ .x = try args.read(u32), .y = try args.read(u32) },
            } },
            .@"set-velocity" => .{ .jump_to = .{
                .id = try args.read(usize),
                .velocity = .{ .x = try args.read(i32), .y = try args.read(i32) },
            } },
            .help => .help,
            .@"print-board", .pr => .{ .print = .{ .board = true, .minotaurs = true } },
        };
    }

    pub fn run(this: Command, dbg: *Debugger) !void {
        switch (this) {
            .noop => {},
            .dump_minotaur => {},
            .dump_all => try utils.println("{}", .{dbg.labyrinth}),
            .step_one => {},
            .step_all => |amnt| {
                var n = @as(usize, 0);
                while (n < amnt) : (n += 1) {
                    try dbg.labyrinth.stepAllMinotaurs();
                }
            },
            .print => |info| {
                const stdout = std.io.getStdOut().writer();
                if (info.board) {
                    try dbg.labyrinth.printBoard(stdout);
                    if (info.minotaurs) try stdout.writeByte('\n');
                }
                if (info.minotaurs) try dbg.labyrinth.printMinotaurs(stdout);
            },
            .quit => unreachable, // should be handled in minotaur
            .jump_to => |j| {
                var minotaur = try dbg.labyrinth.getMinotaur(j.id);
                minotaur.is_first = false;
                if (j.position) |p| minotaur.position = p;
                if (j.velocity) |v| minotaur.velocity = v;
            },
            .help => try utils.println(
                \\ commands:
                \\   d, dump [id] - dumps the minotaur at `id`; dumps the program without id.
                \\   j, jump id posX posY veloX veloY - sets the position & velocity of a minotaur
                \\   set-position id posX posY - sets the position of a minotaur
                \\   set-velocity id veloX veloY - sets the velocity of a minotaur
                \\   q, quit - stops the interpreter
                \\   s, step [amnt=1] - steps all minotaurs `amnt` times
                \\   sm, stepm id [amnt=1] - steps just the minotuar `id` `amnt` times.
                \\   help - prints this
                \\   pr, print-board - prints the board
            , .{}),
        }
    }
};
