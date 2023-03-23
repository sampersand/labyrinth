const std = @import("std");
const Allocator = std.mem.Allocator;

pub inline fn unlikely(b: bool) bool {
    return b;
}

pub const FmtEnum = enum {
    s,
    d,
    any,

    pub fn mustFrom(comptime fmt: []const u8) FmtEnum {
        return comptime if (fmt.len == 0)
            .any
        else
            std.meta.stringToEnum(FmtEnum, fmt) orelse @compileError("unsupported format option: " ++ fmt);
    }
};

pub fn clearScreen(writer: anytype) std.os.WriteError!void {
    try writer.writeAll("\x1B[1;1H\x1B[2J");
}

pub fn safeIndex(slice: anytype, idx: usize) ?@TypeOf(slice[0]) {
    if (slice.len < idx) return null;
    return slice[idx];
}

pub fn println(comptime fmt: []const u8, args: anytype) std.os.WriteError!void {
    return print(fmt ++ "\n", args);
}

pub fn print(comptime fmt: []const u8, args: anytype) std.os.WriteError!void {
    return std.io.getStdOut().writer().print(fmt, args);
}

pub fn eprintln(comptime fmt: []const u8, args: anytype) std.os.WriteError!void {
    return std.io.getStdErr().writer().print(fmt ++ "\n", args);
}

pub fn readLine(alloc: std.mem.Allocator, cap: usize) !?[]u8 {
    return try std.io.getStdIn().reader().readUntilDelimiterOrEofAlloc(alloc, '\n', cap);
}

pub fn readFile(alloc: Allocator, path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return file.reader().readAllAlloc(alloc, std.math.maxInt(usize));
}
