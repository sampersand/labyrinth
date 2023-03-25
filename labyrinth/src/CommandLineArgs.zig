const std = @import("std");
const Allocator = std.mem.Allocator;
const CommandLineArgs = @This();
const Labyrinth = @import("Labyrinth.zig");
const Maze = @import("Maze.zig");
const utils = @import("utils.zig");

iter: std.process.ArgIterator,
alloc: Allocator,
options: Labyrinth.Options,
filename: ?[]const u8 = null,
expr: ?[]const u8 = null,

pub fn init(alloc: Allocator) !CommandLineArgs {
    var iter = try std.process.ArgIterator.initWithAllocator(alloc);
    var options = Labyrinth.Options{
        .program_name = iter.next() orelse return error.NoProgramName,
    };

    return CommandLineArgs{ .alloc = alloc, .iter = iter, .options = options };
}

pub fn createLabyrinth(cla: CommandLineArgs) !Labyrinth {
    var maze: Maze = undefined;

    if (cla.filename) |filename| {
        var contents = try utils.readFile(cla.alloc, filename);
        defer cla.alloc.free(contents);
        maze = try Maze.init(cla.alloc, filename, contents);
    } else if (cla.expr) |expr| {
        maze = try Maze.init(cla.alloc, "-e", expr);
    } else {
        cla.stop(.err, "either `-e` or a filename must be given", .{});
    }

    errdefer maze.deinit(cla.alloc);

    return try Labyrinth.init(cla.alloc, maze, cla.options);
}

pub fn deinit(cla: *CommandLineArgs) void {
    cla.iter.deinit();
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
    cla: *const CommandLineArgs,
    comptime status: Status,
    comptime fmt: []const u8,
    fmtArgs: anytype,
) noreturn {
    stopNoPrefix(status, "{s}: " ++ fmt, .{cla.options.program_name} ++ fmtArgs);
}

fn stopNoPrefix(comptime status: Status, comptime fmt: []const u8, fmt_args: anytype) noreturn {
    const printFunc = if (status == .ok) utils.println else utils.eprintln;

    printFunc(fmt, fmt_args) catch @panic("cant stop with prefix?");
    std.process.exit(if (status == .ok) 0 else 1);
}

fn nextPositional(cla: *CommandLineArgs, option: Option) []const u8 {
    return cla.iter.next() orelse {
        cla.stop(.err, "missing positional argument for {s}", .{std.meta.tagName(option)});
    };
}

pub fn parse(cla: *CommandLineArgs) !void {
    while (cla.iter.next()) |flagname| {
        // ignore empty flags
        if (flagname.len == 0)
            continue;

        const option = std.meta.stringToEnum(Option, flagname) orelse {
            if (flagname[0] == '-') cla.stop(.err, "unknown flag: {s}", .{flagname});
            cla.filename = flagname;
            break;
        };

        switch (option) {
            .@"-" => {
                cla.filename = "-";
                break;
            },
            .@"-h", .@"--help" => cla.writeUsage(),
            .@"-v", .@"--version" => writeVersion(),
            .@"-d", .@"--debug" => cla.options.debug = true,
            .@"-e", .@"--expr" => {
                cla.expr = cla.nextPositional(option);
                break;
            },
            .@"--chdir" => try std.os.chdir(cla.nextPositional(option)),
        }
    }
}

const version = "1.0";

fn writeVersion() noreturn {
    stopNoPrefix(.ok, "v{s}", .{version});
}

fn writeUsage(cla: *const CommandLineArgs) noreturn {
    stopNoPrefix(.ok,
        \\Labyrinth {s}
        \\usage: {s} [flags] (-e expr | filename)
        \\flags:
        \\  -h        shows cla
        \\  -v        prints version
        \\  -d        enables debug mode
        \\If a file is `-`, data is read from stdin.
        \\
    , .{ version, cla.options.program_name });
}
