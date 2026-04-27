const std = @import("std");

const unicode = @import("unicode/unicode.zig");
const utils = @import("utils.zig");

pub var show_search_window: bool = false;
pub var should_focus_search_bar: bool = true;
pub var results_buf: [256]Result = undefined;
pub var results_len: usize = 0;
pub inline fn results() []Result {
    return results_buf[0..results_len];
}
pub var query_buf: [128]u8 = undefined;
pub var query_readonly: []u8 = &.{}; // this field should not be set outside of this module, only read
pub const CharacterSearchResult = struct {
    code_point: unicode.CodePoint,
    name: []const u8,
    containing_block: *const unicode.Block,
};
pub const Result = union(enum) {
    /// When users type in a specific code point they'd like to go straight to
    code_point: CharacterSearchResult,
    block: *const unicode.Block,
    character: CharacterSearchResult,
};

pub fn searchAll(query: []u8) void {
    query_readonly = query;
    results_len = 0;
    code_point: {
        const query_to_check = if (std.mem.startsWith(u8, query, "U+") or std.mem.startsWith(u8, query, "u+")) query[2..] else query;
        const possible_code_point = std.fmt.parseInt(u21, query_to_check, 16) catch break :code_point;
        if (unicode.getBlockThatContainsCodePoint(possible_code_point)) |block| {
            const name = unicode.getCharName(possible_code_point, block) orelse "";
            addToResults(.{
                .code_point = .{
                    .code_point = possible_code_point,
                    .name = name,
                    .containing_block = block,
                },
            });
        }
        break :code_point;
    }
    searchBlocksByName(query);
    if (results_len < results_buf.len)
        searchCharactersByName(query);
}
fn searchBlocksByName(query: []u8) void {
    for (unicode.blocks) |*block| {
        if (utils.isNeedleInHaystack(block.name, query, false)) {
            addToResults(.{ .block = block });
            if (results_len == results_buf.len) return;
        }
    }
}
fn searchCharactersByName(query: []u8) void {
    for (unicode.blocks) |*block| {
        if (unicode.char_names.get(block.name)) |bytes| {
            if (bytes.len == 0) continue;
            const num_header_entries = std.mem.readInt(u16, @ptrCast(bytes[0..]), .little);
            for (0..num_header_entries) |i| {
                const name_addr_addr = (i * @sizeOf(u32)) + @sizeOf(u16);
                const name_addr = std.mem.readInt(u32, @ptrCast(bytes[name_addr_addr..]), .little);
                if (name_addr == 0) continue;
                const name_len = bytes[name_addr];
                const name = bytes[name_addr + 1 .. name_addr + name_len + 1];
                if (utils.isNeedleInHaystack(name, query, true)) {
                    const code_point: unicode.CodePoint = @intCast(i + block.range.start);
                    addToResults(.{
                        .character = .{
                            .code_point = code_point,
                            .name = name,
                            .containing_block = block,
                        },
                    });
                    if (results_len == results_buf.len) {
                        return;
                    }
                }
            }
        }
    }
}
fn addToResults(res: Result) void {
    results_buf[results_len] = res;
    results_len += 1;
}
pub fn clearSearchResultsAndCloseWindow() void {
    clearSearchResults();
    should_focus_search_bar = true;
    show_search_window = false;
    @memset(&query_buf, 0);
}
pub fn clearSearchResults() void {
    results_len = 0;
    query_readonly = &.{};
}
