const std = @import("std");

pub const blocks: []const Block = @import("blocks.zon");
const html_names: []const []const u8 = @import("html_names.zon");
pub const char_names: std.StaticStringMap([]const u8) = .initComptime(blk: {
    var name_bins: [blocks.len]struct { []const u8, []const u8 } = undefined;
    @setEvalBranchQuota(std.math.maxInt(u32));
    for (blocks, 0..) |block, i| {
        const file_path = std.fmt.comptimePrint("names-bins/{s}.bin", .{block.chars_names_bin_filename});
        name_bins[i] = .{ block.name, @embedFile(file_path) };
    }
    break :blk name_bins;
});

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
/// Get the Unicode name for a character
pub fn getCharName(code_point: CodePoint, current_block: *const Block) ?[]const u8 {
    if (char_names.get(current_block.name)) |bytes| {
        const code_point_header_addr = (code_point - current_block.range.start) * @sizeOf(u32);
        const char_name_addr = std.mem.readInt(u32, @ptrCast(bytes[code_point_header_addr..]), .little);
        if (char_name_addr == 0) return null;
        const char_name_len = bytes[char_name_addr];
        return bytes[char_name_addr + 1 .. char_name_addr + 1 + char_name_len];
    }
    return null;
}
pub const CodePointRange = struct {
    start: CodePoint,
    end: CodePoint,
};
pub const Block = struct {
    range: CodePointRange,
    name: []const u8,
    supported_font: []const u8,
    chars_names_bin_filename: []const u8, // TODO see if I can get rid of this
};
