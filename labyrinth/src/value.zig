const std = @import("std");

pub const IntType = i63;
const Array = struct {
    rc: i32,
    eles: std.ArrayList(Value),
};

pub const Value = union(i64) {
    int: i64,
    ary: *Array,

    pub fn dump(this: Value, writer: anytype) std.os.WriteError!void {
        switch (this) {
            .int => |int| try writer.print("{d}", int),
            .ary => |ary| {
                _ = try writer.write("[");
                for (ary.eles.items) |value, idx| {
                    if (idx != 0) {
                        _ = try value.write(", ");
                    }
                    try value.dump(writer);
                }
                _ = try writer.write("]");
            },
        }
    }

    pub fn isint(this: Value) bool {
        return this.num & 1 == 0;
    }

    pub fn from_int(int: IntType) Value {
        return .{ .int = (@as(int, i64) << 1) | 1 };
    }

    pub fn from_array(ary: *Array) Value {
        std.debug.assert((ary & 1) == 0);
        return .{ .ary = ary };
    }

    pub fn is_truthy(this: Value) bool {
        return switch (this) {
            .int => |int| int != 0,
            .ary => |ary| ary.eles.len != 0,
        };
    }

    pub fn len(this: Value) usize {
        return switch (this) {
            .int => 1,
            .ary => |ary| ary.eles.len,
        };
    }
};

// integer parse_int(VALUE v);
// array *to_string(VALUE v);
// array *aalloc(int size);
// void afree(array *a);
// void dump_value(VALUE v, FILE *f);
// void apush(array *a, VALUE v);
// void print(VALUE v, FILE *f);
// VALUE apop(array *a, int i);
// VALUE map(VALUE l, VALUE r, integer (*fn)(integer, integer));
// static inline integer _v_add(integer l, integer r) { return l + r; }
// static inline integer _v_sub(integer l, integer r) { return l - r; }
// static inline integer _v_mul(integer l, integer r) { return l * r; }
// static inline integer _v_div(integer l, integer r) { return l / r; }
// static inline integer _v_mod(integer l, integer r) { return l % r; }
// static inline integer _v_lth(integer l, integer r) { return l < r; }
// static inline integer _v_gth(integer l, integer r) { return l > r; }
// static inline integer _v_cmp(integer l, integer r) { return l < r ? -1 : l == r ? 0 : 1; }

// static inline VALUE vadd(VALUE l, VALUE r) { return map(l, r, _v_add); }
// static inline VALUE vsub(VALUE l, VALUE r) { return map(l, r, _v_sub); }
// static inline VALUE vmul(VALUE l, VALUE r) { return map(l, r, _v_mul); }
// static inline VALUE vdiv(VALUE l, VALUE r) { return map(l, r, _v_div); }
// static inline VALUE vmod(VALUE l, VALUE r) { return map(l, r, _v_mod); }
// int eql(VALUE l, VALUE r);
// static inline VALUE vlth(VALUE l, VALUE r) { return map(l, r, _v_lth); }
// static inline VALUE vgth(VALUE l, VALUE r) { return map(l, r, _v_gth); }
// static inline VALUE vcmp(VALUE l, VALUE r) { return map(l, r, _v_cmp); }

// VALUE duplicate(VALUE v);
// static inline VALUE clone(VALUE v) {
//     if (!isint(v)) ARY(v)->rc++;
//     return v;
// }

// static inline void drop(VALUE v) {
//     if (!isint(v)) afree(ARY(v));
// }

// static inline VALUE chr(VALUE v) {
//     if (isint(v)) {
//         array *a = aalloc(1);
//         a->items[a->len++] = v;
//         return a2v(a);
//     }
//     return clone(v);
// }

// static inline VALUE ord(VALUE v) {
//     die("todo");
//     // if (isint(v)) {
//     //  array *a = aalloc(1);
//     //  a->items[a->len++] = v;
//     //  return a2v(a);
//     // }
//     // return clone(v);
// }
// //  case FCHR: push(p, chr(args[0])); break;
// //  case FORD: push(p, ord(args[0])); break;
