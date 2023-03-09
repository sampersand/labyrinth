const std = @import("std");
const Board = @This();

pub fn deinit(this: *Board) void {
    _ = this;
}

pub fn dump(this: *const Board, writer: anytype) std.os.WriteError!void {
    _ = writer;
    _ = this;
}
