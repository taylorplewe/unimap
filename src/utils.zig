const std = @import("std");
const toLower = std.ascii.toLower;

/// Optimized substr search. Produces far less machine code than `std.mem.containsAtLeast()`.
/// Inspired by the optimized (-O3) machine code output from C++'s `std::basic_string_view<char>::contains()`
pub fn isNeedleInHaystackCaseInsensitive(haystack: []const u8, needle: []const u8) bool {
    // remove some unnecessary checks from the machine code output
    if (haystack.len == 0 or needle.len == 0) unreachable;
    if (needle.len > haystack.len) return false;

    var haystack_sub = haystack;
    while (getFirstIndexOfCharInSlice(haystack_sub[0 .. haystack_sub.len - (needle.len - 1)], needle[0])) |i| {
        if (doSlicesMatchN(haystack_sub[i..], needle)) return true;
        haystack_sub = haystack_sub[i + 1 ..];
    }
    return false;
}
fn getFirstIndexOfCharInSlice(haystack: []const u8, targ_c: u8) ?usize {
    for (haystack, 0..) |c, i| {
        if (toLower(c) == toLower(targ_c)) return i;
    }
    return null;
}
/// Do the first (needle.len) bytes of `haystack` match those of `needle`
fn doSlicesMatchN(haystack: []const u8, needle: []const u8) bool {
    for (needle, haystack[0..needle.len]) |c_n, c_h| {
        if (toLower(c_n) != toLower(c_h)) return false;
    }
    return true;
}
