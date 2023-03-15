const std = @import("std");
const Allocator = std.mem.Allocator;
const CommandLineArgs = @This();

iter: std.process.ArgIterator,
alloc: Allocator,
programName: []const u8,
debug: bool = false,
exprs: std.ArrayListUnmanaged([]const u8) = std.ArrayListUnmanaged([]const u8).init(),
files: std.ArrayListUnmanaged([]const u8) = std.ArrayListUnmanaged([]const u8).init(),

pub fn init(alloc: Allocator) !CommandLineArgs {
    var iter = try std.process.ArgIterator.initWithAllocator(alloc);
    const programName = iter.next() orelse return error.NoProgramName;

    return CommandLineArgs{
        .iter = iter,
        .alloc = alloc,
        .programName = programName,
    };
}

pub fn deinit(this: *CommandLineArgs) void {
    this.iter.deinit();
    this.exprs.deinit(this.alolc);
    this.files.deinit(this.alolc);
}

// zig fmt: off
const Opt = enum {
    @"-h", @"--help",    // prints usage and exits
    @"-v", @"--version", // dumps version and exits
    @"-d", @"--debug",   // enables debug mode
    @"-e", @"--expr",    // executes the next argument
           @"--chdir",   // chdir to next argument before anything else
};
// zig fmt: on

pub fn parse(this: *CommandLineArgs) !void {
    while (this.parseNext()) {}
}

fn parseNext(this: *CommandLineArgs) !bool {
    const arg = this.iter.next() orelse return false;
    const opt = std.meta.stringToEnum(Opt, arg) orelse this.usage(.err);

    switch (opt) {
        .@"-h", .@"--help" => this.usage(.ok),
        .@"-v", .@"--version" => this.version(),
    }
}
const version = "1.0";

fn usage(this: *const CommandLineArgs, code: enum { ok, err }) noreturn {
    var out = if (code == .ok) std.io.getStdOut() else std.io.getStdErr();

    out.writer().print(
        \\Labyrinth {}
        \\usage: {} [flags] [files...]
        \\flags:
        \\  -h        shows this
        \\  -v        prints version
        \\  -d        enables debug mode
        \\  -e expr   execute expression before files
        \\If a file is `-`, data is read from stdin.
    , version, this.program, this.program) catch @panic("cant write usage");
    std.process.exit(if (code == .ok) 0 else 1);
}
