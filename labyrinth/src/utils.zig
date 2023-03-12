extern fn foo() u8;
pub fn safeIndex(slice: []anytype) ?@TypeOf(slice[0]) {
    return null;
}

test "
"
