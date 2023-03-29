const std = @import("std");
const Labyrinth = @import("Labyrinth.zig");
const Allocator = std.mem.Allocator;
const MinotaurId = Labyrinth.MinotaurId;
const utils = @import("utils.zig");
const Debugger = @This();
const Coordinate = @import("Coordinate.zig");
const Vector = @import("Vector.zig");

labyrinth: *Labyrinth,
run_each_step: std.ArrayListUnmanaged(*Command) = .{},
command: Command = Command.noop,

pub fn init(labyrinth: *Labyrinth) !Debugger {
    // var run_each_step = try std.ArrayListUnmanaged(*Command).initCapacity(labyrinth.allocator, 1);

    return .{ .labyrinth = labyrinth };
}

pub fn deinit(debugger: *Debugger) void {
    for (debugger.run_each_step.items) |cmd|
        debugger.labyrinth.allocator.destroy(cmd);
    debugger.run_each_step.deinit(debugger.labyrinth.allocator);
}

pub fn run(dbg: *Debugger) !void {
    const stdout = std.io.getStdOut().writer();
    var stdin = std.io.getStdIn().reader();
    var line_buf: [2048]u8 = undefined;
    var context: Command.ParseContext = undefined;

    while (!dbg.labyrinth.isDone()) {
        _ = b: {
            for (dbg.run_each_step.items) |cmd| {
                cmd.run(dbg) catch |e| break :b e;
            }

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

            const cmdOpt = Command.parse(dbg.labyrinth.allocator, line, &context) catch |e| break :b e;

            if (cmdOpt) |cmd| dbg.command = cmd;
            if (dbg.command == Command.quit) break;
            break :b dbg.command.run(dbg);
        } catch {
            try utils.eprintln("{}", .{context});
        };
    }
}
pub const ArgParser = struct {
    iter: std.mem.TokenIterator(u8),
    ctx: *Command.ParseContext,
    cmd_name: []const u8,

    pub fn initFromOld(argp: *ArgParser) !ArgParser {
        const cmd_name = argp.iter.next() orelse return argp.ctx.fail(error.TooFewArgs, argp.cmd_name);
        return .{ .ctx = argp.ctx, .iter = argp.iter, .cmd_name = cmd_name };
    }

    pub fn init(line: []const u8, ctx: *Command.ParseContext) ?ArgParser {
        var iter = std.mem.tokenize(u8, line, &std.ascii.whitespace);
        const cmd_name = iter.next() orelse return null;
        return .{ .ctx = ctx, .iter = iter, .cmd_name = cmd_name };
    }

    pub fn next(argp: *ArgParser) ?[]const u8 {
        return argp.iter.next();
    }

    pub fn nextReq(argp: *ArgParser) ![]const u8 {
        return argp.next() orelse return argp.ctx.fail(error.TooFewArgs, argp.cmd_name);
    }

    pub fn read(argp: *ArgParser, comptime T: type) !T {
        return try argp.readOrNull(T) orelse argp.ctx.fail(error.TooFewArgs, argp.cmd_name);
    }

    pub fn readOr(argp: *ArgParser, comptime T: type, default: T) !T {
        return try argp.readOrNull(T) orelse default;
    }

    pub fn readOrNull(argp: *ArgParser, comptime T: type) !?T {
        return switch (T) {
            Coordinate => .{ .x = try argp.read(Coordinate.CoordInt), .y = try argp.read(Coordinate.CoordInt) },
            Vector => .{ .x = try argp.read(Vector.VecInt), .y = try argp.read(Vector.VecInt) },
            else => std.fmt.parseInt(T, argp.next() orelse return null, 10) catch |err| argp.ctx.fail(error.CantParseInt, err),
        };
    }
};

const Command = union(enum) {
    pub const ParseError = error{ UnknownCommandName, TooFewArgs, CantParseInt } || Allocator.Error;
    pub const ParseContext = union(enum) {
        UnknownCommandName: []const u8,
        TooFewArgs: []const u8,
        CantParseInt: std.fmt.ParseIntError,

        fn fail(ctx: *@This(), comptime err: ParseError, value: anytype) ParseError {
            ctx.* = @unionInit(@This(), std.meta.tagName(err), value);
            return err;
        }
    };

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
        sticky, sk,
        @"print-maze", pr,
    };
    // zig fmt: on

    dump: ?MinotaurId,
    jump_to: struct { id: MinotaurId, position: ?Coordinate = null, velocity: ?Vector = null },
    step: struct { minotaur: ?MinotaurId = null, amount: usize },
    noop: void,
    help: void,
    quit: void,
    sticky: *Command,
    print: struct { maze: bool, minotaurs: bool },

    fn parse(alloc: Allocator, line: []const u8, ctx: *ParseContext) ParseError!?Command {
        var args = ArgParser.init(line, ctx) orelse return null;
        return try Command.parseWithParser(alloc, &args, ctx);
    }

    fn parseWithParser(alloc: Allocator, args: *ArgParser, ctx: *ParseContext) ParseError!Command {
        const cmd = std.meta.stringToEnum(Names, args.cmd_name) orelse
            return ctx.fail(error.UnknownCommandName, args.cmd_name);

        return switch (cmd) {
            .dump, .d => .{ .dump = try args.readOrNull(MinotaurId) },
            .quit, .q => .quit,
            .step, .s => .{ .step = .{ .amount = try args.readOr(usize, 1) } },
            .stepm, .sm => .{ .step = .{
                .minotaur = try args.read(MinotaurId),
                .amount = try args.readOr(usize, 1),
            } },
            .jump, .j => .{ .jump_to = .{
                .id = try args.read(MinotaurId),
                .position = try args.read(Coordinate),
                .velocity = try args.read(Vector),
            } },
            .@"set-position" => .{ .jump_to = .{
                .id = try args.read(MinotaurId),
                .position = try args.read(Coordinate),
            } },
            .@"set-velocity" => .{ .jump_to = .{
                .id = try args.read(MinotaurId),
                .velocity = try args.read(Vector),
            } },
            .sticky, .sk => .{ .sticky = b: {
                var ptr = try alloc.create(Command);
                errdefer alloc.destroy(ptr);

                var argp2 = try args.initFromOld();
                ptr.* = try Command.parseWithParser(alloc, &argp2, ctx);
                break :b ptr;
            } },
            .help => .help,
            .@"print-maze", .pr => .{ .print = .{ .maze = true, .minotaurs = true } },
        };
    }

    pub fn run(command: Command, dbg: *Debugger) !void {
        const stdout = dbg.labyrinth.stdout.writer();
        switch (command) {
            .quit => unreachable, // should be handled in Debugger.run
            .noop => {},
            .dump => |id_opt| {
                if (id_opt) |id| {
                    try stdout.print("{}\n", .{try dbg.labyrinth.getMinotaur(id)});
                } else {
                    try stdout.print("{}\n", .{dbg.labyrinth});
                }
            },
            .step => |step| {
                if (step.minotaur) |minotaur| {
                    for (utils.range(step.amount)) |_|
                        _ = try dbg.labyrinth.tickMinotaur(minotaur);
                } else {
                    for (utils.range(step.amount)) |_|
                        try dbg.labyrinth.stepAllMinotaurs();
                }
            },
            .print => |info| {
                if (info.maze) {
                    try dbg.labyrinth.printMaze(stdout);
                    if (info.minotaurs) try stdout.writeByte('\n');
                }

                if (info.minotaurs)
                    try dbg.labyrinth.printMinotaurs(stdout);
            },
            .jump_to => |jmp| {
                var minotaur = try dbg.labyrinth.getMinotaur(jmp.id);
                minotaur.is_first = false;
                if (jmp.position) |p| minotaur.jumpTo(p);
                if (jmp.velocity) |v| minotaur.velocity = v;
            },
            .sticky => |ptr| try dbg.run_each_step.append(dbg.labyrinth.allocator, ptr),
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
                \\   pr, print-maze - prints the maze
            , .{}),
        }
    }
};
