const std = @import("std");
const Allocator = std.mem.Allocator;
const CommandLineArgs = @This();
const Labyrinth = @import("Labyrinth.zig");
const Board = @import("Board.zig");
const utils = @import("utils.zig");

iter: std.process.ArgIterator,
program_name: []const u8,
alloc: Allocator,
options: Labyrinth.Options = .{},
filename: ?[]const u8 = null,
expr: ?[]const u8 = null,

pub fn init(alloc: Allocator) !CommandLineArgs {
    var iter = try std.process.ArgIterator.initWithAllocator(alloc);
    const program_name = iter.next() orelse return error.NoProgramName;

    return CommandLineArgs{ .alloc = alloc, .iter = iter, .program_name = program_name };
}

pub fn createLabyrinth(this: CommandLineArgs) !Labyrinth {
    var board: Board = undefined;

    if (this.filename) |filename| {
        var contents = try utils.readFile(this.alloc, filename);
        defer this.alloc.free(contents);
        board = try Board.init(this.alloc, filename, contents);
    } else if (this.expr) |expr| {
        board = try Board.init(this.alloc, "-e", expr);
    } else {
        this.stop(.err, "either `-e` or a filename must be given", .{});
    }

    errdefer board.deinit(this.alloc);

    return try Labyrinth.init(this.alloc, board, this.options);
}

pub fn deinit(this: *CommandLineArgs) void {
    this.iter.deinit();
}

// zig fmt: off
const Option = enum {
    @"-", // read from stdin
    @"-h", @"--help",    // prints usage and exits
    @"-v", @"--version", // dumps version and exits
    @"-d", @"--debug",   // enables debug mode
    @"-e", @"--expr",    // executes the next argument
           @"--chdir",   // chdir to next argument before anything else
};
// zig fmt: on

const Status = enum { ok, err };
fn stop(
    this: *const CommandLineArgs,
    comptime status: Status,
    comptime fmt: []const u8,
    fmtArgs: anytype,
) noreturn {
    stopNoPrefix(status, "{s}: " ++ fmt, .{this.program_name} ++ fmtArgs);
}

fn stopNoPrefix(comptime status: Status, comptime fmt: []const u8, fmt_args: anytype) noreturn {
    const printFunc = if (status == .ok) utils.println else utils.eprintln;

    printFunc(fmt, fmt_args) catch @panic("cant stop with prefix?");
    std.process.exit(if (status == .ok) 0 else 1);
}

fn nextPositional(this: *CommandLineArgs, option: Option) []const u8 {
    return this.iter.next() orelse {
        this.stop(.err, "missing positional argument for {s}", .{std.meta.tagName(option)});
    };
}

pub fn parse(this: *CommandLineArgs) !void {
    while (this.iter.next()) |flagname| {
        // ignore empty flags
        if (flagname.len == 0)
            continue;

        const option = std.meta.stringToEnum(Option, flagname) orelse {
            if (flagname[0] == '-') this.stop(.err, "unknown flag: {s}", .{flagname});
            this.filename = flagname;
            break;
        };

        switch (option) {
            .@"-" => {
                this.filename = "-";
                break;
            },
            .@"-h", .@"--help" => this.writeUsage(),
            .@"-v", .@"--version" => writeVersion(),
            .@"-d", .@"--debug" => this.options.debug = true,
            .@"-e", .@"--expr" => {
                this.expr = this.nextPositional(option);
                break;
            },
            .@"--chdir" => try std.os.chdir(this.nextPositional(option)),
        }
    }
}

const version = "1.0";

fn writeVersion() noreturn {
    stopNoPrefix(.ok, "v{s}", .{version});
}

fn writeUsage(this: *const CommandLineArgs) noreturn {
    stopNoPrefix(.ok,
        \\Labyrinth {s}
        \\usage: {s} [flags] (-e expr | filename)
        \\flags:
        \\  -h        shows this
        \\  -v        prints version
        \\  -d        enables debug mode
        \\If a file is `-`, data is read from stdin.
        \\
    , .{ version, this.program_name });
}
