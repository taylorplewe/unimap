const std = @import("std");

const html_names: []const []const u8 = @import("html_names.zon");

pub const PHYSICAL_CHAR_VALUE_ALLOC_SIZE = 8;

pub const CodePoint = u21;
/// Get the HTML entity name (e.g. "&copy;") for a Unicode character
/// The returned string may be allocated on the stack, and as such, this function must be inlined
pub inline fn getHtmlNameFromCodePoint(code_point: CodePoint) []const u8 {
    var html_name_buf: [16]u8 = undefined;
    return switch (code_point) {
        0xa0...0x17f => html_names[code_point - 0xa0],
        else => std.fmt.bufPrint(&html_name_buf, "&#x{X};", .{code_point}) catch unreachable,
    };
}
pub const CodePointRange = struct {
    start: CodePoint,
    end: CodePoint,
};
pub const Block = struct {
    range: CodePointRange,
    name: []const u8,
    supported_font: []const u8,
};
