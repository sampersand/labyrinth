const std = @import("std");
const Allocator = std.mem.Allocator;
const CommandLineArgs = @This();
const Labyrinth = @import("Labyrinth.zig");
const Board = @import("Board.zig");
const utils = @import("utils.zig");

iter: std.process.ArgIterator,
programName: []const u8,
alloc: Allocator,
options: Labyrinth.Options = .{},
fileName: ?[]const u8 = null,
expr: ?[]const u8 = null,

pub fn init(alloc: Allocator) !CommandLineArgs {
    var iter = try std.process.ArgIterator.initWithAllocator(alloc);
    const programName = iter.next() orelse return error.NoProgramName;

    return CommandLineArgs{ .alloc = alloc, .iter = iter, .programName = programName };
}

pub fn createLabyrinth(this: CommandLineArgs) !Labyrinth {
    var board: Board = undefined;

    if (this.fileName) |fileName| {
        var contents = try utils.readFile(this.alloc, fileName);
        defer this.alloc.free(contents);
        board = try Board.init(this.alloc, fileName, contents);
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
    status: Status,
    comptime fmt: []const u8,
    fmtArgs: anytype,
) noreturn {
    stopNoPrefix(status, "{s}: " ++ fmt, .{this.programName} ++ fmtArgs);
}

fn stopNoPrefix(status: Status, comptime fmt: []const u8, fmtArgs: anytype) noreturn {
    var out = if (status == .ok) std.io.getStdOut() else std.io.getStdErr();

    out.writer().print(fmt ++ "\n", fmtArgs) catch @panic("cant abort");
    std.process.exit(if (status == .ok) 0 else 1);
}

fn nextPositional(this: *CommandLineArgs, option: Option) []const u8 {
    return this.iter.next() orelse {
        this.stop(.err, "missing positional argument for {s}", .{std.meta.tagName(option)});
    };
}

pub fn parse(this: *CommandLineArgs) !void {
    while (this.iter.next()) |flagName| {
        // ignore empty flags
        if (flagName.len == 0)
            continue;

        const option = std.meta.stringToEnum(Option, flagName) orelse {
            if (flagName[0] == '-') this.stop(.err, "unknown flag: {s}", .{flagName});
            this.fileName = flagName;
            break;
        };

        switch (option) {
            .@"-" => {
                this.fileName = "-";
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
    , .{ version, this.programName });
}
