const std = @import("std");
const dvui = @import("dvui");

const View = @import("views/View.zig");
const character_list = @import("views/character_list.zig");
const block_select = @import("views/block_select.zig");
const unicode = @import("unicode/unicode.zig");
const utils = @import("utils.zig");
const search = @import("search.zig");
const search_window = @import("views/components/search_window.zig");
const upper_bar = @import("views/components/upper_bar.zig");

const App = @This();

state: State = .{ .BlockSelect = .{} },
/// The state to switch to at the very end of this frame
next_state: ?State = null,

const Mode = enum {
    BlockSelect,
    CharacterList,
};
pub const State = union(Mode) {
    BlockSelect: BlockSelectState,
    CharacterList: CharacterListState,
};
const BlockSelectState = struct {
    block_to_focus: ?*const unicode.Block = null,
};
const CharacterListState = struct {
    block: *const unicode.Block,
    char_to_focus: ?unicode.CodePoint = null,
};
const views: std.EnumMap(Mode, View) = .init(.{
    .BlockSelect = .{ .doFrame = block_select.doFrame },
    .CharacterList = .{ .doFrame = character_list.doFrame },
});

pub fn frame(self: *App) void {
    upper_bar.doFrame(self);

    var scroll = dvui.scrollArea(
        @src(),
        .{},
        .{ .expand = .both, .style = .window },
    );
    defer scroll.deinit();

    views.getAssertContains(self.state).doFrame(self);

    if (search.show_search_window)
        search_window.doFrame(self);

    if (self.next_state) |next_state| {
        switch (next_state) {
            .CharacterList => scroll.si.scrollToOffset(.vertical, 0),
            else => {},
        }
        self.state = next_state;
        self.next_state = null;
    }
}
