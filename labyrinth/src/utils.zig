pub fn safeIndex(slice: anytype, idx: usize) ?@TypeOf(slice[0]) {
    if (slice.len < idx) return null;
    return slice[idx];
}
