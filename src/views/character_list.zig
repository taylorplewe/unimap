const std = @import("std");
const dvui = @import("dvui");

const App = @import("../App.zig");
const unicode = @import("../unicode/unicode.zig");

pub fn frame(app: *App) void {
    var scroll = dvui.scrollArea(
        @src(),
        .{},
        .{ .expand = .both, .style = .window },
    );
    defer scroll.deinit();

    if (dvui.button(@src(), "Back to blocks", .{}, .{})) {
        app.state = .BlockSelect;
        return;
    }

    dvui.labelNoFmt(@src(), app.state.CharacterList.name, .{}, .{});

    {
        var flex = dvui.flexbox(@src(), .{}, .{ .expand = .horizontal });
        defer flex.deinit();

        var physical: [unicode.PHYSICAL_CHAR_VALUE_ALLOC_SIZE]u8 = undefined;
        for (app.state.CharacterList.range.start..app.state.CharacterList.range.end + 1) |i| {
            const num_bytes = std.unicode.utf8Encode(@intCast(i), &physical) catch unreachable;
            if (dvui.button(@src(), physical[0..num_bytes], .{}, .{ .id_extra = i })) {
                std.debug.print("pressed: {}\n", .{i});
            }
        }
    }
}
