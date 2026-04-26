const std = @import("std");

const unicode = @import("unicode/unicode.zig");
const utils = @import("utils.zig");

pub var results_buf: [256]Result = undefined;
pub var results_len: ?usize = null;
pub inline fn results() []Result {
    return if (results_len) |len| results_buf[0..len] else &.{};
}
pub var query_buf: [128]u8 = undefined;
pub const CharacterSearchResult = struct {
    code_point: unicode.CodePoint,
    name: []const u8,
    containing_block: *const unicode.Block,
};
pub const Result = union(enum) {
    block: *const unicode.Block,
    character: CharacterSearchResult,
};

pub fn searchCharactersByName(query: []u8) void {
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
                    results_buf[results_len.?] = .{
                        .character = .{
                            .code_point = code_point,
                            .name = name,
                            .containing_block = block,
                        },
                    };
                    results_len.? += 1;
                    if (results_len.? == results_buf.len) {
                        return;
                    }
                }
            }
        }
    }
}
pub fn clearSearchResults() void {
    results_len = null;
    @memset(&query_buf, 0);
}
