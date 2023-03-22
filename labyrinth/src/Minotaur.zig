const std = @import("std");
const Allocator = std.mem.Allocator;
const Minotaur = @This();
const Labyrinth = @import("Labyrinth.zig");
const Coordinate = @import("Coordinate.zig");
const Vector = @import("Vector.zig");
const Value = @import("Value.zig");
const Function = @import("function.zig").Function;
const IntType = @import("types.zig").IntType;
const Array = @import("Array.zig");
const Maze = @import("Maze.zig");

const utils = @import("utils.zig");
const build_options = @import("build-options");
const positions_count = build_options.prev_positions + 1;

allocator: Allocator,
stack: std.ArrayListUnmanaged(Value),

velocity: Vector = Vector.Right,
positions: [positions_count]Coordinate = .{Coordinate.Origin} ** positions_count,

// We keep arguments here so we can check them in the debugger.
args: [Function.MaxArgc]Value = undefined,
mode: union(enum) { normal, integer: IntType, string: *Array } = .normal,
steps_ahead: usize = 0,
is_first: bool = false,
colour: u8 = 0,
exit_status: ?u8 = null,

/// Creates a new `Minotaur` with the given starting stack capacity.
pub fn initCapacity(alloc: Allocator, cap: usize) Allocator.Error!Minotaur {
    return .{
        .stack = try std.ArrayListUnmanaged(Value).initCapacity(alloc, cap),
        .allocator = alloc,
    };
}

/// Deinitializes the minotaur and all associated items.
pub fn deinit(minotaur: *Minotaur) void {
    for (minotaur.stack.items) |item|
        item.deinit(minotaur.allocator);
    minotaur.stack.deinit(minotaur.allocator);

    switch (minotaur.mode) {
        .string => |ary| ary.deinit(minotaur.allocator),
        else => {},
    }
}

pub inline fn hasExited(minotaur: *const Minotaur) bool {
    return minotaur.exit_status != null;
}

/// Moves the minotaur to the `new` position, updating old positions as needed.
pub fn jumpTo(minotaur: *Minotaur, new: Coordinate) void {
    var i: usize = positions_count - 1;
    while (i != 0) : (i -= 1) {
        minotaur.positions[i] = minotaur.positions[i - 1];
    }

    minotaur.positions[0] = new;
}

/// Moves the minotaur forward by `minotaur.velocity` steps.
pub fn advance(minotaur: *Minotaur) Coordinate.MoveError!void {
    std.debug.assert(!minotaur.hasExited());

    minotaur.jumpTo(try minotaur.positions[0].moveBy(minotaur.velocity));
}

pub const StackError = error{StackTooSmall};

/// Helper function to return an index from the end, or an error if it's too small.
inline fn offset(minotaur: *const Minotaur, fromEnd: usize) StackError!usize {
    if (minotaur.stack.items.len <= fromEnd) return error.StackTooSmall;
    return minotaur.stack.items.len - fromEnd - 1;
}
/// Pushes `value` onto the end of the stack.
pub fn push(minotaur: *Minotaur, value: Value) Allocator.Error!void {
    try minotaur.stack.append(minotaur.allocator, value);
}

/// Get the `idx`th element from the top of the stack, or return an error.
pub fn dup(minotaur: *const Minotaur, fromEnd: usize) StackError!Value {
    return minotaur.stack.items[try minotaur.offset(fromEnd)].clone();
}

/// Removes the `fromEnd`th element from the stack, returning an error if that's not possible.
pub fn pop(minotaur: *Minotaur, fromEnd: usize) StackError!Value {
    const index = try minotaur.offset(fromEnd);
    return switch (fromEnd) {
        0 => minotaur.stack.pop(),
        1 => minotaur.stack.swapRemove(index),
        else => minotaur.stack.orderedRemove(index),
    };
}

/// Prints a debug representation of `minotaur` out.
pub fn format(
    minotaur: *const Minotaur,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) std.os.WriteError!void {
    try writer.print(
        "Minotaur{{position={any},velocity={any},stack=[",
        .{ minotaur.positions[0], minotaur.velocity },
    );

    for (minotaur.stack.items) |*value, idx| {
        if (idx != 0) try writer.writeAll(", ");
        try writer.print("{}", .{value});
    }

    try writer.writeAll("]}");
}

pub fn clone(minotaur: *const Minotaur) Allocator.Error!Minotaur {
    var new = try Minotaur.initCapacity(minotaur.allocator, minotaur.stack.items.len);

    for (minotaur.stack.items) |value|
        new.push(value.clone()) catch unreachable; // we ensured we had enough capacity.

    new.positions = minotaur.positions;
    new.velocity = minotaur.velocity;
    new.colour = minotaur.colour +% 1;
    new.mode = minotaur.mode;
    new.steps_ahead = minotaur.steps_ahead;
    new.is_first = minotaur.is_first;
    new.colour = minotaur.colour;
    new.exit_status = minotaur.exit_status;
    // No need to copy `args` over.

    return new;
}

/// The same as `Minotaur.clone`, except it also rotates in the given direction.
pub fn cloneRotate(minotaur: *const Minotaur, dir: Vector.Direction) Allocator.Error!Minotaur {
    var copy = try minotaur.clone();
    copy.velocity = copy.velocity.rotate(dir);
    return copy;
}

pub fn step(minotaur: *Minotaur, labyrinth: *Labyrinth) PlayError!void {
    if (minotaur.steps_ahead != 0) {
        minotaur.steps_ahead -= 1;
        return;
    }

    if (minotaur.is_first) {
        minotaur.is_first = false;
    } else try minotaur.advance();
    const byte = try labyrinth.maze.get(minotaur.positions[0]);

    switch (minotaur.mode) {
        .normal => {},
        .integer => |*int| {
            if (parseDigit(byte)) |digit| {
                int.* = 10 * int.* + digit;
                return;
            }

            try minotaur.push(Value.from(int.*));
            minotaur.mode = .normal;
        },
        .string => |ary| {
            if (byte != comptime Function.str.toByte()) {
                try ary.push(minotaur.allocator, Value.from(@intCast(IntType, byte)));
            } else {
                try minotaur.push(Value.from(ary));
                minotaur.mode = .normal;
            }

            return;
        },
    }

    return minotaur.traverse(labyrinth, Function.fromByte(byte) catch |err| {
        return std.log.err("error: {}", .{err});
    });
}

fn setArguments(minotaur: *Minotaur, arity: usize) PlayError!void {
    var i: usize = 0;
    errdefer minotaur.deinitArgs(i);

    while (i < arity) : (i += 1)
        minotaur.args[i] = minotaur.pop(0) catch return error.TooFewArgumentsForFunction;
}

fn deinitArgs(minotaur: *Minotaur, arity: usize) void {
    for (minotaur.args[0..arity]) |arg|
        arg.deinit(minotaur.allocator);
}

const PlayError = error{
    TooFewArgumentsForFunction,
    IntOutOfBounds,
    StackTooSmall,
    StackTooLarge,
} || Maze.GetError || std.os.WriteError || Allocator.Error ||
    Array.ParseIntError || Function.ValidateError || Value.OrdError || Value.MathError ||
    Coordinate.MoveError;

fn parseDigit(byte: u8) ?IntType {
    return if ('0' <= byte and byte <= '9') @as(IntType, byte - '0') else null;
}

fn castInt(comptime T: type, int: IntType) PlayError!T {
    return std.math.cast(T, int) orelse return error.IntOutOfBounds;
}

fn jumpn(minotaur: *Minotaur, n: Value) PlayError!void {
    const CoordInt = i32;
    const int = try n.toInt();
    const scalar = try castInt(CoordInt, int);
    minotaur.positions[0] = try minotaur.positions[0].moveBy(minotaur.velocity.scale(scalar));
}

fn randomVelocity(rng: *std.rand.DefaultPrng) Vector {
    return switch (rng.random().int(u2)) {
        0b00 => Vector.Up,
        0b01 => Vector.Down,
        0b10 => Vector.Left,
        0b11 => Vector.Right,
    };
}

fn traverse(minotaur: *Minotaur, labyrinth: *Labyrinth, function: Function) PlayError!void {
    std.debug.assert(minotaur.steps_ahead == 0);

    try minotaur.setArguments(function.arity());
    defer minotaur.deinitArgs(function.arity());
    var return_value: ?Value = null;

    switch (function) {
        .int0, .int1, .int2, .int3, .int4, .int5, .int6, .int7, .int8, .int9 => minotaur.mode = .{
            .integer = parseDigit(function.toByte()) orelse unreachable,
        },
        .str => minotaur.mode = .{ .string = try Array.init(minotaur.allocator) },
        .dumpq, .dump => {
            try utils.println("{any}", .{labyrinth});
            if (function == .dumpq) minotaur.exit_status = 0;
        },
        .quit0 => minotaur.exit_status = 0,
        .quit => minotaur.exit_status = try castInt(u8, try minotaur.args[0].toInt()),

        .moveh, .movev => {
            const perpendicular = 0 != if (function == .moveh) minotaur.velocity.x else minotaur.velocity.y;
            if (!perpendicular) {
                // TODO: when `@cold` comes out make the `!perpendicular` branch cold.
                try labyrinth.spawnMinotaur(try minotaur.cloneRotate(.left));
                minotaur.velocity = minotaur.velocity.rotate(.right);
            }
        },
        .left => minotaur.velocity = Vector.Left,
        .right => minotaur.velocity = Vector.Right,
        .up => minotaur.velocity = Vector.Up,
        .down => minotaur.velocity = Vector.Down,
        .speedup => minotaur.velocity = minotaur.velocity.speedUp(),
        .slowdown => minotaur.velocity = minotaur.velocity.slowDown(),
        .jump1 => try minotaur.advance(),
        .jump => try minotaur.jumpn(minotaur.args[0]),
        .dup1 => return_value = try minotaur.dup(1),
        .dup2 => return_value = try minotaur.dup(2),
        .dup => return_value = try minotaur.dup(try castInt(usize, try minotaur.args[0].toInt())),
        .pop1 => {},
        .pop2 => _ = try minotaur.pop(2),
        .pop => _ = try minotaur.pop(try castInt(usize, try minotaur.args[0].toInt())),
        .swap => return_value = try minotaur.pop(2),
        .stacklen => return_value = Value.from(
            std.math.cast(IntType, minotaur.stack.items.len) orelse return error.StackTooLarge,
        ),

        .ifr, .ifl => if (!minotaur.args[0].isTruthy()) {
            minotaur.velocity = minotaur.velocity.rotate(if (function == .ifl) .left else .right);
        },
        .ifpop => _ = try minotaur.pop(if (minotaur.args[0].isTruthy()) 2 else 1),
        .unlessjump1 => if (!minotaur.args[0].isTruthy()) try minotaur.advance(),
        .unlessjump => if (!minotaur.args[0].isTruthy()) try minotaur.jumpn(minotaur.args[1]),
        .ifjump1 => if (minotaur.args[0].isTruthy()) try minotaur.advance(),
        .ifjump => if (minotaur.args[0].isTruthy()) try minotaur.jumpn(minotaur.args[1]),

        .rand => return_value = Value.from(labyrinth.rng.random().int(IntType)),
        .randdir => minotaur.velocity = randomVelocity(&labyrinth.rng),
        .dumpvalnl => try utils.println("{d}", .{minotaur.args[0]}),
        .dumpval => try utils.print("{d}", .{minotaur.args[0]}),

        .printnl, .print => {
            var writer = std.io.getStdOut().writer();
            try writer.print("{s}", .{minotaur.args[0]});
            if (function == .printnl) try writer.writeAll("\n");
        },

        .inccolour => minotaur.colour +%= 1,
        .setcolour => minotaur.colour = @bitCast(u8, @truncate(i8, try minotaur.args[0].toInt())),

        .sleep1 => minotaur.steps_ahead = 1,
        .sleep => minotaur.steps_ahead = try castInt(usize, try minotaur.args[0].toInt()),

        .spawnl => try labyrinth.spawnMinotaur(try minotaur.cloneRotate(.left)),
        .spawnr => try labyrinth.spawnMinotaur(try minotaur.cloneRotate(.right)),

        .inc => return_value = try minotaur.args[0].add(minotaur.allocator, Value.from(1)),
        .dec => return_value = try minotaur.args[0].sub(minotaur.allocator, Value.from(1)),
        .add => return_value = try minotaur.args[1].add(minotaur.allocator, minotaur.args[0]),
        .sub => return_value = try minotaur.args[1].sub(minotaur.allocator, minotaur.args[0]),
        .mul => return_value = try minotaur.args[1].mul(minotaur.allocator, minotaur.args[0]),
        .div => return_value = try minotaur.args[1].div(minotaur.allocator, minotaur.args[0]),
        .mod => return_value = try minotaur.args[1].mod(minotaur.allocator, minotaur.args[0]),
        .neg => return_value = try minotaur.args[0].mul(minotaur.allocator, Value.from(-1)),

        .not => return_value = Value.from(!minotaur.args[0].isTruthy()),
        .eql => return_value = Value.from(minotaur.args[1].equals(minotaur.args[0])),
        .lth => return_value = Value.from(minotaur.args[1].cmp(minotaur.args[0]) < 0),
        .gth => return_value = Value.from(minotaur.args[1].cmp(minotaur.args[0]) > 0),
        .cmp => return_value = Value.from(minotaur.args[1].cmp(minotaur.args[0])),

        .ary, .ary_end, .slay1, .slay, .gets, .get, .set => @panic("todo"),

        .toi => return_value = Value.from(try minotaur.args[0].toInt()),
        .tos => return_value = Value.from(try minotaur.args[0].toArray(minotaur.allocator)),

        .ord => return_value = try minotaur.args[0].ord(),
        .chr => return_value = try minotaur.args[0].chr(minotaur.allocator),
        .len => return_value = Value.from(
            std.math.cast(IntType, minotaur.args[0].len()) orelse return error.IntOutOfBounds,
        ),
    }

    if (return_value) |value| try minotaur.push(value);
}
