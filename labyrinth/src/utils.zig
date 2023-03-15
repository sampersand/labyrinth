const std = @import("std");

pub fn clearScreen(writer: anytype) std.os.WriteError!void {
    try writer.writeAll("\x1B[1;1H\x1B[2J");
}

pub fn safeIndex(slice: anytype, idx: usize) ?@TypeOf(slice[0]) {
    if (slice.len < idx) return null;
    return slice[idx];
}

pub fn readLine(alloc: std.mem.Allocator, cap: usize) !?[]u8 {
    return try std.io.getStdIn().reader().readUntilDelimiterOrEofAlloc(alloc, '\n', cap);
}
