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
    for (this.stack.items) |item|
        item.deinit(this.allocator);
    this.stack.deinit(this.allocator);
}

pub fn step(this: *Minotaur) void {
    this.position = this.position.add(this.velocity);
}

pub fn unstep(this: *Minotaur) void {
    this.position = this.position.sub(this.velocity);
}

pub const StackError = error{StackTooSmall};

pub fn nth(this: *const Minotaur, idx: usize) StackError!Value {
    std.debug.assert(idx != 0);
    if (this.stack.items.len < idx)
        return error.StackTooSmall;
    return this.stack.items[this.stack.items.len - idx];
}

pub fn dupn(this: *const Minotaur, idx: usize) StackError!Value {
    return (try this.nth(idx)).clone();
}

pub fn push(this: *Minotaur, value: Value) Allocator.Error!void {
    try this.stack.append(this.allocator, value);
}

pub fn pop(this: *Minotaur) StackError!Value {
    return this.stack.pop();
}

pub fn popn(this: *Minotaur, idx: usize) StackError!Value {
    if (this.stack.items.len < idx)
        return error.StackTooSmall;

    return switch (idx) {
        0 => @panic("popn(0)"),
        1 => this.stack.pop(),
        2 => this.stack.swapRemove(this.stack.items.len - 2),
        else => this.stack.orderedRemove(this.stack.items.len - idx),
    };
}

pub fn format(
    this: *const Minotaur,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.print("Minotaur{{position={any},velocity={any},stack=[", .{ this.position, this.velocity });
    for (this.stack.items) |*value, idx| {
        if (idx != 0) try writer.writeAll(", ");
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
    const chr = try labyrinth.board.get(this.position);

    switch (this.mode) {
        .Normal => {},
        .Integer => |*int| {
            if (parseDigit(chr)) |digit| {
                int.* = 10 * int.* + digit;
                return PlayResult.Continue;
            }

            try this.push(Value.from(int.*));
            this.mode = .Normal;
        },
        .String => |ary| {
            if (chr != comptime Function.Str.toByte()) {
                try ary.push(this.allocator, Value.from(@intCast(IntType, chr)));
            } else {
                try this.push(Value.from(ary));
                this.mode = .Normal;
            }

            return PlayResult.Continue;
        },
    }

    return this.traverse(labyrinth, try Function.fromChar(chr));
}

fn setArguments(this: *Minotaur, arity: usize) PlayError!void {
    var i: usize = 0;
    errdefer this.deinitArgs(i);

    while (i < arity) : (i += 1)
        this.args[i] = this.pop() catch return error.TooFewArgumentsForFunction;
}

fn deinitArgs(this: *Minotaur, arity: usize) void {
    for (this.args[0..arity]) |arg|
        arg.deinit(this.allocator);
}

const PlayError = error{
    TooFewArgumentsForFunction,
    IntOutOfBounds,
    StackTooSmall,
    StackTooLarge,
} || Board.GetError || std.os.WriteError || Allocator.Error ||
    Array.ParseIntError || Function.ValidateError || Value.OrdError || Value.MathError;

const PlayResult = union(enum) {
    Continue,
    Exit: i32,
};

fn parseDigit(byte: u8) ?IntType {
    return if ('0' <= byte and byte <= '9') @as(IntType, byte - '0') else null;
}

pub fn clone(this: *const Minotaur) Allocator.Error!Minotaur {
    var stack = try std.ArrayListUnmanaged(Value).initCapacity(this.allocator, this.stack.items.len);
    for (this.stack.items) |value|
        try stack.append(this.allocator, value.clone());

    return Minotaur{
        .position = this.position,
        .velocity = this.velocity,
        .allocator = this.allocator,
        .mode = this.mode,
        .stack = stack,
    };
}

pub fn cloneRotate(this: *const Minotaur, dir: Coordinate.Direction) Allocator.Error!Minotaur {
    var copy = try this.clone();
    errdefer copy.deinit();
    copy.velocity = copy.velocity.rotate(dir);
    return copy;
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
    var returnValue: ?Value = null;

    switch (function) {
        .I0, .I1, .I2, .I3, .I4, .I5, .I6, .I7, .I8, .I9 => this.mode = .{
            .Integer = parseDigit(function.toByte()) orelse unreachable,
        },
        .Str => this.mode = .{ .String = try Array.init(this.allocator) },
        .DumpQ, .Dump => {
            var writer = std.io.getStdOut().writer();
            try writer.print("{any}\n", .{labyrinth});
            if (function == .DumpQ) return PlayResult{ .Exit = 0 };
        },
        .Quit0 => return PlayResult{ .Exit = 0 },
        .Quit => return PlayResult{ .Exit = try castInt(i32, try this.args[0].toInt()) },

        .MoveH, .MoveV => {
            const perpendicular = 0 != if (function == .MoveH) this.velocity.x else this.velocity.y;
            if (!perpendicular) {
                try labyrinth.spawnMinotaur(try this.cloneRotate(.left));
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
            if (this.velocity.eql(Coordinate.Origin)) this.velocity = this.velocity.sub(dir);
        },

        .Jump1 => this.step(),
        .JumpN => try this.jumpn(this.args[0]),
        .Dup => returnValue = try this.dupn(1),
        .Dup2 => returnValue = try this.dupn(2),
        .DupN => returnValue = try this.dupn(try castInt(usize, try this.args[0].toInt())),
        .Pop => {},
        .Pop2 => _ = try this.popn(2),
        .PopN => returnValue = try this.popn(try castInt(usize, try this.args[0].toInt())),
        .Swap => returnValue = try this.popn(2),
        .StackLen => returnValue = Value.from(
            std.math.cast(IntType, this.stack.items.len) orelse return error.StackTooLarge,
        ),

        .IfL, .IfR => if (!this.args[0].isTruthy()) {
            this.velocity = this.velocity.rotate(if (function == .IfR) .right else .left);
        },
        .IfPop => _ = try this.popn(if (this.args[0].isTruthy()) 2 else 1),
        .JumpUnless => if (!this.args[0].isTruthy()) this.step(),
        .JumpNUnless => if (!this.args[0].isTruthy()) try this.jumpn(this.args[1]),

        .Rand => returnValue = Value.from(labyrinth.rng.random().int(IntType)),
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

        .PrintNL, .Print => {
            var writer = std.io.getStdOut().writer();
            try this.args[0].print(writer);
            if (function == .PrintNL) try writer.writeAll("\n");
        },

        .Sleep1 => this.stepsAhead = 1,
        .SleepN => this.stepsAhead = try castInt(usize, try this.args[0].toInt()),

        .SpawnL => try labyrinth.spawnMinotaur(try this.cloneRotate(.left)),
        .SpawnR => try labyrinth.spawnMinotaur(try this.cloneRotate(.right)),

        .Inc => returnValue = try this.args[0].add(this.allocator, Value.from(1)),
        .Dec => returnValue = try this.args[0].sub(this.allocator, Value.from(1)),
        .Add => returnValue = try this.args[1].add(this.allocator, this.args[0]),
        .Sub => returnValue = try this.args[1].sub(this.allocator, this.args[0]),
        .Mul => returnValue = try this.args[1].mul(this.allocator, this.args[0]),
        .Div => returnValue = try this.args[1].div(this.allocator, this.args[0]),
        .Mod => returnValue = try this.args[1].mod(this.allocator, this.args[0]),

        .Not => returnValue = Value.from(!this.args[1].isTruthy()),
        .Eql => returnValue = Value.from(this.args[1].equals(this.args[0])),
        .Lth => returnValue = Value.from(this.args[1].cmp(this.args[0]) < 0),
        .Gth => returnValue = Value.from(this.args[1].cmp(this.args[0]) > 0),
        .Cmp => returnValue = Value.from(this.args[1].cmp(this.args[0])),

        .Ary, .AryEnd, .Ifpopold, .Slay1, .SlayN, .Gets, .Get, .Set => @panic("todo"),

        .ToI => returnValue = Value.from(try this.args[0].toInt()),
        .ToS => returnValue = Value.from(try this.args[0].toString(this.allocator)),

        .Ord => returnValue = try this.args[0].ord(),
        .Chr => returnValue = try this.args[0].chr(this.allocator),
        .Len => returnValue = Value.from(
            std.math.cast(IntType, this.args[0].len()) orelse return error.IntOutOfBounds,
        ),
    }

    if (returnValue) |value| try this.push(value);

    return PlayResult.Continue;
}
