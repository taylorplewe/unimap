const std = @import("std");

const View = @import("views/View.zig");
const character_list = @import("views/character_list.zig");
const block_select = @import("views/block_select.zig");
const unicode = @import("unicode/unicode.zig");
const utils = @import("utils.zig");

const App = @This();

state: State = .BlockSelect,
/// The state to switch to at the very end of this frame
next_state: State = .BlockSelect,

const Mode = enum {
    BlockSelect,
    CharacterList,
};
pub const State = union(Mode) {
    BlockSelect,
    CharacterList: CharacterListState,
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
    views.getAssertContains(self.state).doFrame(self);
    self.state = self.next_state;
}
