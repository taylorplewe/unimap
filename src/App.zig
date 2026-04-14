const std = @import("std");

const View = @import("views/View.zig");
const character_list = @import("views/character_list.zig");
const block_select = @import("views/block_select.zig");
const unicode = @import("unicode/unicode.zig");

pub const blocks: []const unicode.Block = @import("unicode/blocks.zon");
pub const supported_fonts: []const []const u8 = @import("unicode/supported_fonts.zon");
pub var clipboard_buf: [8]u16 = undefined; // Windows expects UTF-16 Unicode data

const App = @This();

state: State = .BlockSelect,

const Mode = enum {
    BlockSelect,
    CharacterList,
};
const CharacterListState = struct {
    selected_block_index: usize,
    selected_block: *const unicode.Block,
};
pub const State = union(Mode) {
    BlockSelect,
    CharacterList: CharacterListState,
};
const views: std.EnumMap(Mode, View) = .init(.{
    .BlockSelect = .{ .frame = block_select.frame },
    .CharacterList = .{ .frame = character_list.frame },
});

pub fn frame(self: *App) void {
    views.getAssertContains(self.state).frame(self);
}
