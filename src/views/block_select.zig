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

    for (App.blocks) |block| {
        var clicked = false;
        {
            var block_btn: dvui.ButtonWidget = undefined;
            defer block_btn.deinit();
            block_btn.init(@src(), .{}, .{ .id_extra = block.range.start, .expand = .horizontal });
            block_btn.processEvents();
            block_btn.drawBackground();
            clicked = block_btn.clicked();

            var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
            dvui.labelNoFmt(
                @src(),
                block.name,
                .{},
                .{
                    .expand = .horizontal,
                    .font = dvui.Font.theme(.body).withSize(8),
                },
            );
            dvui.label(
                @src(),
                "U+{X} - U+{X}",
                .{ block.range.start, block.range.end },
                .{
                    .color_text = .fromHex("#aaa"),
                    .font = dvui.Font.theme(.body).withSize(6),
                    .gravity_y = 0.5,
                },
            );
            hbox.deinit();

            block_btn.drawFocus();
        }
        if (clicked) {
            app.state = .{ .CharacterList = &block };
        }
    }
}
