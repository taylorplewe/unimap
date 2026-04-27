const std = @import("std");
const toLower = std.ascii.toLower;
const toUpper = std.ascii.toUpper;

/// Optimized substr search. Produces far less machine code than `std.mem.containsAtLeast()`.
/// Inspired by the optimized (-O3) machine code output from C++'s `std::basic_string_view<char>::contains()`
/// WARNING: calling this function with an empty haystack or needle will panic
pub fn isNeedleInHaystack(haystack: []const u8, needle: []const u8, comptime is_upper_haystack: bool) bool {
    // remove some unnecessary checks from the machine code output
    if (haystack.len == 0 or needle.len == 0) unreachable;
    if (needle.len > haystack.len) return false;

    var haystack_sub = haystack;
    while (getFirstIndexOfCharInSlice(haystack_sub[0 .. haystack_sub.len - (needle.len - 1)], needle[0], is_upper_haystack)) |i| {
        if (doSlicesMatchN(haystack_sub[i..], needle, is_upper_haystack)) return true;
        haystack_sub = haystack_sub[i + 1 ..];
    }
    return false;
}
fn getFirstIndexOfCharInSlice(haystack: []const u8, targ_c: u8, comptime is_upper_haystack: bool) ?usize {
    for (haystack, 0..) |c, i| {
        switch (is_upper_haystack) {
            true => if (c == toUpper(targ_c)) return i,
            false => if (toLower(c) == toLower(targ_c)) return i,
        }
    }
    return null;
}
/// Do the first (needle.len) bytes of `haystack` match those of `needle`
fn doSlicesMatchN(haystack: []const u8, needle: []const u8, comptime is_upper_haystack: bool) bool {
    for (needle, haystack[0..needle.len]) |c_n, c_h| {
        switch (is_upper_haystack) {
            true => if (toUpper(c_n) != c_h) return false,
            false => if (toLower(c_n) != toLower(c_h)) return false,
        }
    }
    return true;
}

/// Like `(std.Io.Reader).takeInt()` or `std.mem.readInt()`, but no reader needed. Generates less machine code.
/// Unsafe? Very
pub inline fn getIntFromDataAtOffs(comptime T: type, data: []const u8, offs: usize) T {
    return @as(*T, @ptrCast(@alignCast(@constCast(data[offs..])))).*;
}
