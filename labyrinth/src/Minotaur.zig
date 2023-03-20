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
mode: union(enum) { normal, integer: IntType, string: *Array } = .normal,
steps_ahead: usize = 0,
is_first: bool = false,
colour: u8,
exit_status: ?u8 = null,
prev_positions: [5]Coordinate = .{Coordinate.Origin} ** 5,

pub fn initCapacity(alloc: Allocator, cap: usize) Allocator.Error!Minotaur {
    return Minotaur{
        .stack = try std.ArrayListUnmanaged(Value).initCapacity(alloc, cap),
        .allocator = alloc,
        .colour = 0,
    };
}

pub fn deinit(this: *Minotaur) void {
    for (this.stack.items) |item|
        item.deinit(this.allocator);
    this.stack.deinit(this.allocator);
}

pub fn advance(this: *Minotaur) Coordinate.MoveError!void {
    std.debug.assert(!this.hasExited());
    var i: usize = 4;
    while (i != 0) : (i -= 1) {
        this.prev_positions[i] = this.prev_positions[i - 1];
    }
    this.prev_positions[0] = this.position;
    this.position = try this.position.moveBy(this.velocity);
}

pub const StackError = error{StackTooSmall};
pub fn nth(this: *const Minotaur, idx: usize) StackError!Value {
    std.debug.assert(idx != 0);
    if (this.stack.items.len < idx) return error.StackTooSmall;
    return this.stack.items[this.stack.items.len - idx];
}

pub fn hasExited(this: *const Minotaur) bool {
    return this.exit_status != null;
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
    if (this.steps_ahead != 0) {
        this.steps_ahead -= 1;
        return;
    }

    if (this.is_first) {
        this.is_first = false;
    } else try this.advance();
    const byte = try labyrinth.board.get(this.position);

    switch (this.mode) {
        .normal => {},
        .integer => |*int| {
            if (parseDigit(byte)) |digit| {
                int.* = 10 * int.* + digit;
                return;
            }

            try this.push(Value.from(int.*));
            this.mode = .normal;
        },
        .string => |ary| {
            if (byte != comptime Function.str.toByte()) {
                try ary.push(this.allocator, Value.from(@intCast(IntType, byte)));
            } else {
                try this.push(Value.from(ary));
                this.mode = .normal;
            }

            return;
        },
    }

    return this.traverse(labyrinth, Function.fromByte(byte) catch |err| {
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
        .colour = this.colour +% 1,
        .mode = this.mode,
        .stack = stack,
        .prev_positions = this.prev_positions,
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
    std.debug.assert(this.steps_ahead == 0);

    try this.setArguments(function.arity());
    defer this.deinitArgs(function.arity());
    var return_value: ?Value = null;

    switch (function) {
        .int0, .int1, .int2, .int3, .int4, .int5, .int6, .int7, .int8, .int9 => this.mode = .{
            .integer = parseDigit(function.toByte()) orelse unreachable,
        },
        .str => this.mode = .{ .string = try Array.init(this.allocator) },
        .dumpq, .dump => {
            try utils.println("{any}", .{labyrinth});
            if (function == .dumpq) this.exit_status = 0;
        },
        .quit0 => this.exit_status = 0,
        .quit => this.exit_status = try castInt(u8, try this.args[0].toInt()),

        .moveh, .movev => {
            const perpendicular = 0 != if (function == .moveh) this.velocity.x else this.velocity.y;
            if (!perpendicular) {
                // TODO: when `@cold` comes out make the `!perpendicular` branch cold.
                try labyrinth.spawnMinotaur(try this.cloneRotate(.left));
                this.velocity = this.velocity.rotate(.right);
            }
        },
        .left => this.velocity = Vector.Left,
        .right => this.velocity = Vector.Right,
        .up => this.velocity = Vector.Up,
        .down => this.velocity = Vector.Down,
        .speedup => this.velocity = this.velocity.speedUp(),
        .slowdown => this.velocity = this.velocity.slowDown(),
        .jump1 => try this.advance(),
        .jump => try this.jumpn(this.args[0]),
        .dup1 => return_value = try this.dupn(1),
        .dup2 => return_value = try this.dupn(2),
        .dup => return_value = try this.dupn(try castInt(usize, try this.args[0].toInt())),
        .pop1 => {},
        .pop2 => _ = try this.popn(2),
        .pop => return_value = try this.popn(try castInt(usize, try this.args[0].toInt())),
        .swap => return_value = try this.popn(2),
        .stacklen => return_value = Value.from(
            std.math.cast(IntType, this.stack.items.len) orelse return error.StackTooLarge,
        ),

        .ifr, .ifl => if (!this.args[0].isTruthy()) {
            this.velocity = this.velocity.rotate(if (function == .ifl) .left else .right);
        },
        .ifpop => _ = try this.popn(if (this.args[0].isTruthy()) 2 else 1),
        .unlessjump1 => if (!this.args[0].isTruthy()) try this.advance(),
        .unlessjump => if (!this.args[0].isTruthy()) try this.jumpn(this.args[1]),
        .ifjump1 => if (this.args[0].isTruthy()) try this.advance(),
        .ifjump => if (this.args[0].isTruthy()) try this.jumpn(this.args[1]),

        .rand => return_value = Value.from(labyrinth.rng.random().int(IntType)),
        .randdir => this.velocity = randomVelocity(&labyrinth.rng),
        .dumpvalnl => try utils.println("{}", .{this.args[0]}),
        .dumpval => try utils.print("{}", .{this.args[0]}),

        .printnl, .print => {
            var writer = std.io.getStdOut().writer();
            try this.args[0].print(writer);
            if (function == .printnl) try writer.writeAll("\n");
        },

        .inccolour => this.colour +%= 1,
        .setcolour => this.colour = @bitCast(u8, @truncate(i8, try this.args[0].toInt())),

        .sleep1 => this.steps_ahead = 1,
        .sleep => this.steps_ahead = try castInt(usize, try this.args[0].toInt()),

        .spawnl => try labyrinth.spawnMinotaur(try this.cloneRotate(.left)),
        .spawnr => try labyrinth.spawnMinotaur(try this.cloneRotate(.right)),

        .inc => return_value = try this.args[0].add(this.allocator, Value.from(1)),
        .dec => return_value = try this.args[0].sub(this.allocator, Value.from(1)),
        .add => return_value = try this.args[1].add(this.allocator, this.args[0]),
        .sub => return_value = try this.args[1].sub(this.allocator, this.args[0]),
        .mul => return_value = try this.args[1].mul(this.allocator, this.args[0]),
        .div => return_value = try this.args[1].div(this.allocator, this.args[0]),
        .mod => return_value = try this.args[1].mod(this.allocator, this.args[0]),
        .neg => return_value = try this.args[0].mul(this.allocator, Value.from(-1)),

        .not => return_value = Value.from(!this.args[0].isTruthy()),
        .eql => return_value = Value.from(this.args[1].equals(this.args[0])),
        .lth => return_value = Value.from(this.args[1].cmp(this.args[0]) < 0),
        .gth => return_value = Value.from(this.args[1].cmp(this.args[0]) > 0),
        .cmp => return_value = Value.from(this.args[1].cmp(this.args[0])),

        .ary, .ary_end, .slay1, .slay, .gets, .get, .set => @panic("todo"),

        .toi => return_value = Value.from(try this.args[0].toInt()),
        .tos => return_value = Value.from(try this.args[0].toString(this.allocator)),

        .ord => return_value = try this.args[0].ord(),
        .chr => return_value = try this.args[0].chr(this.allocator),
        .len => return_value = Value.from(
            std.math.cast(IntType, this.args[0].len()) orelse return error.IntOutOfBounds,
        ),
    }

    if (return_value) |value| try this.push(value);
}
