const std = @import("std");
const Allocator = std.mem.Allocator;
const CommandLineArgs = @This();
const Labyrinth = @import("Labyrinth.zig");
const Maze = @import("Maze.zig");
const Array = @import("Array.zig");
const Value = @import("Value.zig");
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

fn parseShebang(cla: *CommandLineArgs, file: *[]const u8) !void {
    if (file.len < 2 or file.*[0] != '#' or file.*[1] != '!')
        return;

    _ = cla; // todo: Actually parse arguments

    while (file.len != 0 and file.*[0] != '\n') {
        file.* = file.*[1..];
    }

    if (file.len != 0 and file.*[0] == '\n') file.* = file.*[1..];
}

pub fn createLabyrinth(cla: *CommandLineArgs) !Labyrinth {
    var maze: Maze = undefined;

    if (cla.filename) |filename| {
        var contents = try utils.readFile(cla.alloc, filename);
        const orig_contents = contents;
        defer cla.alloc.free(orig_contents);

        try cla.parseShebang(&contents);
        maze = try Maze.init(cla.alloc, filename, contents);
    } else if (cla.expr) |*expr| {
        try cla.parseShebang(expr);
        maze = try Maze.init(cla.alloc, "-e", expr.*);
    } else {
        cla.stop(.err, "either `-e` or a filename must be given", .{});
    }

    var labyrinth = Labyrinth.init(cla.alloc, maze, cla.options) catch |err| {
        maze.deinit(cla.alloc);
        return err;
    };
    errdefer labyrinth.deinit();

    var iter = cla.iter;
    var minotaur = labyrinth.getMinotaur(0) catch unreachable;
    while (iter.next()) |field| {
        const string = try Array.fromString(labyrinth.allocator, field);
        errdefer string.deinit(labyrinth.allocator);

        try minotaur.push(Value.from(string));
    }

    return labyrinth;
}

pub fn deinit(cla: *CommandLineArgs) void {
    cla.iter.deinit();
    cla.* = undefined;
}

// zig fmt: off
const Option = enum {
    @"-", // read from stdin
    @"-h", @"--help",              // prints usage and exits
    @"-v", @"--version",           // dumps version and exits
    @"-d", @"--debug",             // enables debug mode
    @"-e", @"--expr",              // executes the next argument
           @"--chdir",             // chdir to next argument before anything else
    @"-o", @"--output-maze",       // outputs maze at each step.
    @"-m", @"--output-minotaurs",  // outputs minotaurs at each step.
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
        cla.stop(.err, "missing positional argument for {s}", .{@tagName(option)});
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
            .@"-o", .@"--output-maze" => cla.options.print_maze = true,
            .@"-m", .@"--output-minotaurs" => cla.options.print_minotaurs = true,
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
        \\usage: {s} [flags] filename
        \\flags:
        \\  -h --help       shows this
        \\  -v --version    prints version
        \\  -d --debug      enables debug mode
        \\  -e --expr EXPR  runs EXPR; omit `filename`
        \\     --chdir DIR  changes to DIR
        \\  -o --output-maze prints maze at each step
        \\  -m --output-minotaurs prints minotaurs too.
        \\If a file is `-`, data is read from stdin.
        \\
    , .{ version, cla.options.program_name });
}
