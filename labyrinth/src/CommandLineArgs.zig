const std = @import("std");
const Allocator = std.mem.Allocator;
const This = @This();

iter: std.process.ArgIterator,
alloc: Allocator,
programName: []const u8,
debug: bool = false,
exprs: std.ArrayListUnmanaged([]const u8) = .{},
files: std.ArrayListUnmanaged([]const u8) = .{},

pub fn init(alloc: Allocator) !This {
    var iter = try std.process.ArgIterator.initWithAllocator(alloc);
    const programName = iter.next() orelse return error.NoProgramName;

    return This{
        .iter = iter,
        .alloc = alloc,
        .programName = programName,
    };
}

pub fn deinit(this: *This) void {
    this.iter.deinit();
    this.exprs.deinit(this.alloc);
    this.files.deinit(this.alloc);
}

pub fn parse(this: *This) !void {
    while (try this.parseNext()) {}
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

fn nextPositional(this: *This) {

}

fn abort(this: *const This, comptime fmt: []const u8, fmtArgs: anytype) noreturn {
    var stderr = std.io.getStdErr();
    stderr.print("{}: " ++ fmt, .{this.programName} ++ fmtArgs) catch @panic("cant abort");
    std.process.exit(1) ;
}

fn parseNext(this: *This) !bool {
    const arg = this.iter.next() orelse return false;
    const opt = std.meta.stringToEnum(Opt, arg) orelse {
        try std.io.getStderr().print("unknown flag '{}'\ntry `{} --help` for help", arg, this.programName),
        std.process.exit(1) ;

    switch (opt) {
        .@"-h", .@"--help" => this.writeUsage(.ok),
        .@"-v", .@"--version" => this.writeVersion(),
        .@"-d", .@"--debug" => this.debug = true,
        .@"-e", .@"--expr" => @panic("todo"),
        .@"--chdir" => @panic("todo"),
    }

    return true;
}
const version = "1.0";

fn writeVersion(_: *const This) noreturn {
    std.io.getStdOut().writer().writeAll(version) catch @panic("cant write version");
    std.process.exit(0);
}

fn writeUsage(this: *const This, code: enum { ok, err }) noreturn {
    var out = if (code == .ok) std.io.getStdOut() else std.io.getStdErr();

    out.writer().print(
        \\Labyrinth {s}
        \\usage: {s} [flags] [files...]
        \\flags:
        \\  -h        shows this
        \\  -v        prints version
        \\  -d        enables debug mode
        \\  -e expr   execute expression before files
        \\If a file is `-`, data is read from stdin.
        \\
    , .{ version, this.programName }) catch @panic("cant write usage");
    std.process.exit(if (code == .ok) 0 else 1);
}
