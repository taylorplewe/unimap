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

pub const CodePoint = u21;

pub const UTF8_ENCODED_ALLOC_SIZE = 8;
/// Returns a slice (between 1-4 bytes long) that can be used to render a glyph, using a supported font.
///
/// Must be inlined since returned slice is stack-allocated.
pub inline fn getUtf8EncodedChar(code_point: CodePoint) []u8 {
    var utf8_encoded: [UTF8_ENCODED_ALLOC_SIZE]u8 = undefined;
    const num_bytes = std.unicode.utf8Encode(code_point, &utf8_encoded) catch unreachable;
    return utf8_encoded[0..num_bytes];
}
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
pub inline fn getCharName(code_point: CodePoint, current_block: *const Block) ?[]const u8 {
    // some characters are just "<block name>-<code point>"
    var name_buf: [256]u8 = undefined;
    switch (current_block.range.start) {
        0x00f900 => return if (code_point <= 0xfad9) std.fmt.bufPrint(&name_buf, "CJK COMPATIBILITY IDEOGRAPH-{X}", .{code_point}) catch "" else null,
        0x00fe00 => return std.fmt.bufPrint(&name_buf, "VARIATION SELECTOR-{d}", .{(code_point - current_block.range.start) + 1}) catch "",
        0x013460 => return std.fmt.bufPrint(&name_buf, "EGYPTIAN HIEROGLYPH-{X}", .{code_point}) catch "",
        0x018800 => return std.fmt.bufPrint(&name_buf, "TANGUT COMPONENT-{d:0>3}", .{(code_point - current_block.range.start) + 1}) catch "",
        0x018b00 => return std.fmt.bufPrint(&name_buf, "KHITAN SMALL SCRIPT CHARACTER-{X}", .{code_point}) catch "",
        0x018d80 => return std.fmt.bufPrint(&name_buf, "TANGUT COMPONENT-{d:0>3}", .{(code_point - current_block.range.start) + 769}) catch "",
        0x01b170 => return std.fmt.bufPrint(&name_buf, "NUSHU CHARACTER-{X}", .{code_point}) catch "",
        0x02f800 => return std.fmt.bufPrint(&name_buf, "CJK COMPATIBILITY IDEOGRAPH-{X}", .{code_point}) catch "",
        0x0e0100 => return std.fmt.bufPrint(&name_buf, "VARIATION SELECTOR-{d}", .{(code_point - current_block.range.start) + 17}) catch "",
        else => {},
    }
    if (char_names.get(current_block.name)) |bytes| {
        const num_header_entries = std.mem.readInt(u16, @ptrCast(bytes[0..]), .little);
        if (code_point - current_block.range.start >= num_header_entries) return null;

        const code_point_header_addr = ((code_point - current_block.range.start) * @sizeOf(u32)) + @sizeOf(u16);
        if (code_point_header_addr > bytes.len) return null;
        const char_name_addr = std.mem.readInt(u32, @ptrCast(bytes[code_point_header_addr..]), .little);
        if (char_name_addr == 0) return null;
        const char_name_len = bytes[char_name_addr];
        return bytes[char_name_addr + 1 .. char_name_addr + 1 + char_name_len];
    }
    return null;
}
pub fn getBlockThatContainsCodePoint(code_point: CodePoint) ?*const Block {
    for (blocks) |*block| {
        if (block.range.start <= code_point and block.range.end >= code_point) return block;
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
