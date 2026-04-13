const dvui = @import("dvui");

const App = @import("../App.zig");

pub fn frame(app: *App) void {
    var scroll = dvui.scrollArea(
        @src(),
        .{},
        .{ .expand = .both, .style = .window },
    );
    defer scroll.deinit();

    _ = app;
    // TODO: this is crashing the app
    // dvui.labelNoFmt(@src(), app.state.CharacterList.name, .{}, .{});
}
