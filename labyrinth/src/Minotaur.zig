const std = @import("std");
const Allocator = std.mem.Allocator;
const Minotaur = @This();
const Labyrinth = @import("Labyrinth.zig");
const Coordinate = @import("Coordinate.zig");
const Value = @import("value.zig").Value;
const Function = @import("function.zig").Function;
const IntType = @import("types.zig").IntType;
const Array = @import("Array.zig");
const Board = @import("Board.zig");

position: Coordinate = Coordinate.Origin,
velocity: Coordinate = Coordinate.Right,
allocator: Allocator,
stack: std.ArrayListUnmanaged(Value),
args: [Function.MaxArgc]Value = undefined,
mode: union(enum) { Normal, Integer: IntType, String: *Array } = .Normal,
stepsAhead: usize = 0,

pub fn initCapacity(alloc: Allocator, cap: usize) Allocator.Error!Minotaur {
    return Minotaur{
        .stack = try std.ArrayListUnmanaged(Value).initCapacity(alloc, cap),
        .allocator = alloc,
    };
}

pub fn deinit(this: *Minotaur) void {
    for (this.stack.items) |item| {
        item.deinit(this.allocator);
    }

    this.stack.deinit(this.allocator);
}

pub fn step(this: *Minotaur) void {
    this.position = this.position.add(this.velocity);
}

pub fn unstep(this: *Minotaur) void {
    this.position = this.position.sub(this.velocity);
}

pub fn nth(this: *const Minotaur, idx: usize) ?Value {
    std.debug.assert(idx != 0);
    return if (idx <= this.stack.items.len) this.stack.items[this.stack.items.len - idx] else null;
}

pub fn dupn(this: *const Minotaur, idx: usize) ?Value {
    return (this.nth(idx) orelse return null).clone();
}

pub fn push(this: *Minotaur, value: Value) Allocator.Error!void {
    if (false) {
        @panic("oops");
    }
    try this.stack.append(this.allocator, value);
}

pub fn pop(this: *Minotaur) ?Value {
    return this.stack.pop();
}

pub fn popn(this: *Minotaur, idx: usize) ?Value {
    // TODO
    _ = this;
    _ = idx;
    @panic("todo");
}

pub fn format(
    this: *const Minotaur,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    _ = fmt;
    _ = options;
    try writer.print("Minotaur{{position={any},velocity={any},stack=[", .{ this.position, this.velocity });
    for (this.stack.items) |*value, idx| {
        if (idx != 0) {
            try writer.writeAll(", ");
        }
        try writer.print("{}", .{value});
    }

    try writer.print("]}}", .{});
}

pub fn play(this: *Minotaur, labyrinth: *Labyrinth) PlayError!PlayResult {
    if (this.stepsAhead != 0) {
        this.stepsAhead -= 1;
        return PlayResult.Continue;
    }

    this.step();
    const function = try labyrinth.board.get(this.position);

    switch (this.mode) {
        .Normal => {},
        .Integer => |*int| {
            if (parseDigit(function.toByte())) |digit| {
                int.* = 10 * int.* + digit;
                return PlayResult.Continue;
            }

            try this.push(Value.from(int.*));
            this.mode = .Normal;
        },
        .String => @panic("Todo"),
    }

    return this.traverse(labyrinth, function);
}

fn setArguments(this: *Minotaur, arity: usize) PlayError!void {
    var i: usize = 0;
    errdefer this.deinitArgs(i);

    while (i < arity) : (i += 1) {
        this.args[i] = this.pop() orelse return error.TooFewArgumentsForFunction;
    }
}

fn deinitArgs(this: *Minotaur, arity: usize) void {
    for (this.args[0..arity]) |arg| {
        arg.deinit(this.allocator);
    }
}

const PlayError = error{
    TooFewArgumentsForFunction,
    IntOutOfBounds,
    StackTooSmall,
} || Board.GetError || std.os.WriteError || Allocator.Error || Array.ParseIntError;

const PlayResult = union(enum) {
    Continue,
    Exit: i32,
};

fn parseDigit(byte: u8) ?IntType {
    return if ('0' <= byte and byte <= '9') @as(IntType, byte - '0') else null;
}

pub fn clone(this: *Minotaur) Allocator.Error!Minotaur {
    return Minotaur{
        .position = this.position,
        .velocity = this.velocity,
        .allocator = this.allocator,
        .mode = this.mode,
        .stack = try this.stack.clone(this.allocator),
    };
}

fn castInt(comptime T: type, int: IntType) PlayError!T {
    return std.math.cast(T, int) orelse return error.IntOutOfBounds;
}

fn jumpn(this: *Minotaur, n: Value) PlayError!void {
    // const CoordI32 = @TypeOf(Coordinate).
    const CoordInt = i32;
    const int = try n.toInt();
    const scalar = try castInt(CoordInt, int);
    this.position = this.position.add(.{
        .x = this.velocity.x * scalar,
        .y = this.velocity.y * scalar,
    });
}

fn traverse(this: *Minotaur, labyrinth: *Labyrinth, function: Function) PlayError!PlayResult {
    std.debug.assert(this.stepsAhead == 0);

    try this.setArguments(function.arity());
    defer this.deinitArgs(function.arity());

    switch (function) {
        .I0, .I1, .I2, .I3, .I4, .I5, .I6, .I7, .I8, .I9 => this.mode = .{
            .Integer = parseDigit(function.toByte()) orelse unreachable,
        },
        .DumpQ, .Dump => {
            var writer = std.io.getStdOut().writer();
            try writer.print("{any}\n", .{this});
            if (function == .DumpQ) {
                return PlayResult{ .Exit = 0 };
            }
        },
        .Quit0 => return PlayResult{ .Exit = 0 },

        .MoveH, .MoveV => {
            const perpendicular = 0 != if (function == .MoveH) this.velocity.x else this.velocity.y;
            if (!perpendicular) {
                var copy = try this.clone();
                errdefer copy.deinit();
                copy.velocity = copy.velocity.rotate(.left);

                try labyrinth.spawnMinotaur(copy);
                this.velocity = this.velocity.rotate(.right);
            }
        },

        .Left => this.velocity = Coordinate.Left,
        .Right => this.velocity = Coordinate.Right,
        .Up => this.velocity = Coordinate.Up,
        .Down => this.velocity = Coordinate.Down,
        .SpeedUp => this.velocity = this.velocity.add(this.velocity.direction()),
        .SlowDown => {
            const dir = this.velocity.direction();
            this.velocity = this.velocity.sub(dir);
            if (this.velocity.eql(Coordinate.Origin)) {
                this.velocity = this.velocity.sub(dir);
            }
        },
        .Jump1 => this.step(),
        .JumpN => try this.jumpn(this.args[0]),
        .Dup => try this.push(this.dupn(1) orelse return error.StackTooSmall),
        .Dup2 => try this.push(this.dupn(2) orelse return error.StackTooSmall),
        .DupN => @panic("todo"),
        .Pop => {},
        .Pop2 => _ = this.popn(2) orelse return error.StackTooSmall,
        .PopN => @panic("todo"),
        .StackLen => @panic("todo"),

        .IfL, .IfR => if (!this.args[0].isTruthy()) {
            this.velocity = this.velocity.rotate(if (function == .IfR) .right else .left);
        },
        .IfPop => _ = this.popn(if (this.args[0].isTruthy()) 2 else 1) orelse return error.StackTooSmall,
        .JumpUnless => if (!this.args[0].isTruthy()) this.step(),
        .JumpNUnless => if (!this.args[0].isTruthy()) try this.jumpn(this.args[1]),

        .RandDir => switch (labyrinth.rng.random().int(u2)) {
            0b00 => this.velocity = Coordinate.Up,
            0b01 => this.velocity = Coordinate.Down,
            0b10 => this.velocity = Coordinate.Left,
            0b11 => this.velocity = Coordinate.Right,
        },

        .DumpValNL, .DumpVal => {
            var writer = std.io.getStdOut().writer();
            try writer.print("{}", this.args[0]);
            if (function == .DumpValNL) try writer.writeAll("\n");
        },

        .Sleep1 => this.stepsAhead = 1,
        .SleepN => this.stepsAhead = try castInt(usize, try this.args[0].toInt()),

        else => @panic("todo"),
    }

    return PlayResult.Continue;
}
