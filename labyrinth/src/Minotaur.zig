const std = @import("std");
const Allocator = std.mem.Allocator;
const Minotaur = @This();
const Labyrinth = @import("Labyrinth.zig");
const Coordinate = @import("Coordinate.zig");
const Vector = @import("Vector.zig");
const Value = @import("value.zig").Value;
const Function = @import("function.zig").Function;
const IntType = @import("types.zig").IntType;
const Array = @import("Array.zig");
const Board = @import("Board.zig");
const utils = @import("utils.zig");

position: Coordinate = Coordinate.Origin,
velocity: Vector = Vector.Right,
allocator: Allocator,
stack: std.ArrayListUnmanaged(Value),
args: [Function.MaxArgc]Value = undefined,
mode: union(enum) { Normal, Integer: IntType, String: *Array } = .Normal,
stepsAhead: usize = 0,
isFirst: bool = false,
exitStatus: ?u8 = null,
prevPositions: [3]Coordinate = .{Coordinate.Origin} ** 3,

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

pub fn advance(this: *Minotaur) Coordinate.MoveError!void {
    std.debug.assert(!this.hasExited());
    this.prevPositions[2] = this.prevPositions[1];
    this.prevPositions[1] = this.prevPositions[0];
    this.prevPositions[0] = this.position;
    this.position = try this.position.moveBy(this.velocity);
}

pub const StackError = error{StackTooSmall};
pub fn nth(this: *const Minotaur, idx: usize) StackError!Value {
    std.debug.assert(idx != 0);
    if (this.stack.items.len < idx) return error.StackTooSmall;
    return this.stack.items[this.stack.items.len - idx];
}

pub fn hasExited(this: *const Minotaur) bool {
    return this.exitStatus != null;
}

pub fn dupn(this: *const Minotaur, idx: usize) StackError!Value {
    return (try this.nth(idx)).clone();
}

pub fn push(this: *Minotaur, value: Value) Allocator.Error!void {
    try this.stack.append(this.allocator, value);
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

pub fn step(this: *Minotaur, labyrinth: *Labyrinth) PlayError!void {
    if (this.stepsAhead != 0) {
        this.stepsAhead -= 1;
        return;
    }

    if (this.isFirst) {
        this.isFirst = false;
    } else try this.advance();
    const chr = try labyrinth.board.get(this.position);

    switch (this.mode) {
        .Normal => {},
        .Integer => |*int| {
            if (parseDigit(chr)) |digit| {
                int.* = 10 * int.* + digit;
                return;
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

            return;
        },
    }

    return this.traverse(labyrinth, Function.fromChar(chr) catch |err| {
        return std.log.err("error: {}", .{err});
    });
}

fn setArguments(this: *Minotaur, arity: usize) PlayError!void {
    var i: usize = 0;
    errdefer this.deinitArgs(i);

    while (i < arity) : (i += 1)
        this.args[i] = this.popn(1) catch return error.TooFewArgumentsForFunction;
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
    Array.ParseIntError || Function.ValidateError || Value.OrdError || Value.MathError ||
    Coordinate.MoveError;

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
        .prevPositions = this.prevPositions,
    };
}

pub fn cloneRotate(this: *const Minotaur, dir: Vector.Direction) Allocator.Error!Minotaur {
    var copy = try this.clone();
    errdefer copy.deinit();
    copy.velocity = copy.velocity.rotate(dir);
    return copy;
}

fn castInt(comptime T: type, int: IntType) PlayError!T {
    return std.math.cast(T, int) orelse return error.IntOutOfBounds;
}

fn jumpn(this: *Minotaur, n: Value) PlayError!void {
    const CoordInt = i32;
    const int = try n.toInt();
    const scalar = try castInt(CoordInt, int);
    this.position = try this.position.moveBy(this.velocity.scale(scalar));
}

fn randomVelocity(rng: *std.rand.DefaultPrng) Vector {
    return switch (rng.random().int(u2)) {
        0b00 => Vector.Up,
        0b01 => Vector.Down,
        0b10 => Vector.Left,
        0b11 => Vector.Right,
    };
}

fn traverse(this: *Minotaur, labyrinth: *Labyrinth, function: Function) PlayError!void {
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
            try utils.println("{any}", .{labyrinth});
            if (function == .DumpQ) this.exitStatus = 0;
        },
        .Quit0 => this.exitStatus = 0,
        .Quit => this.exitStatus = try castInt(u8, try this.args[0].toInt()),

        .MoveH, .MoveV => {
            const perpendicular = 0 != if (function == .MoveH) this.velocity.x else this.velocity.y;
            if (!perpendicular) {
                // TODO: when `@cold` comes out make the `!perpendicular` branch cold.
                try labyrinth.spawnMinotaur(try this.cloneRotate(.Left));
                this.velocity = this.velocity.rotate(.Right);
            }
        },
        .Left => this.velocity = Vector.Left,
        .Right => this.velocity = Vector.Right,
        .Up => this.velocity = Vector.Up,
        .Down => this.velocity = Vector.Down,
        .SpeedUp => this.velocity = this.velocity.add(this.velocity.direction()),
        .SlowDown => {
            const dir = this.velocity.direction();
            this.velocity = this.velocity.sub(dir);
            if (this.velocity.x == 0 and this.velocity.y == 0) {
                this.velocity = this.velocity.sub(dir);
            }
        },

        .Jump1 => try this.advance(),
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
            this.velocity = this.velocity.rotate(if (function == .IfR) .Right else .Left);
        },
        .IfPop => _ = try this.popn(if (this.args[0].isTruthy()) 2 else 1),
        .JumpUnless => if (!this.args[0].isTruthy()) try this.advance(),
        .JumpNUnless => if (!this.args[0].isTruthy()) try this.jumpn(this.args[1]),

        .Rand => returnValue = Value.from(labyrinth.rng.random().int(IntType)),
        .RandDir => this.velocity = randomVelocity(&labyrinth.rng),
        .DumpValNL => try utils.println("{}", .{this.args[0]}),
        .DumpVal => try utils.print("{}", .{this.args[0]}),

        .PrintNL, .Print => {
            var writer = std.io.getStdOut().writer();
            try this.args[0].print(writer);
            if (function == .PrintNL) try writer.writeAll("\n");
        },

        .Sleep1 => this.stepsAhead = 1,
        .SleepN => this.stepsAhead = try castInt(usize, try this.args[0].toInt()),

        .SpawnL => try labyrinth.spawnMinotaur(try this.cloneRotate(.Left)),
        .SpawnR => try labyrinth.spawnMinotaur(try this.cloneRotate(.Right)),

        .Inc => returnValue = try this.args[0].add(this.allocator, Value.from(1)),
        .Dec => returnValue = try this.args[0].sub(this.allocator, Value.from(1)),
        .Add => returnValue = try this.args[1].add(this.allocator, this.args[0]),
        .Sub => returnValue = try this.args[1].sub(this.allocator, this.args[0]),
        .Mul => returnValue = try this.args[1].mul(this.allocator, this.args[0]),
        .Div => returnValue = try this.args[1].div(this.allocator, this.args[0]),
        .Mod => returnValue = try this.args[1].mod(this.allocator, this.args[0]),

        .Not => returnValue = Value.from(!this.args[0].isTruthy()),
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
}
