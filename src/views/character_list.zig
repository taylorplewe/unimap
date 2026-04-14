const dvui = @import("dvui");

const App = @import("../App.zig");

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

    // _ = app;
    // TODO: this is crashing the app
    dvui.labelNoFmt(@src(), app.state.CharacterList.name, .{}, .{});
}
