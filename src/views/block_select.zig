const std = @import("std");
const dvui = @import("dvui");

const utils = @import("../utils.zig");
const App = @import("../App.zig");
const unicode = @import("../unicode/unicode.zig");
const search = @import("../search.zig");
const search_button = @import("components/search_button.zig");

var go_to_code_point_buf: [6]u8 = undefined;

pub fn doFrame(app: *App) void {
    for (unicode.blocks) |*block| {
        drawBlock(app, block);
    }
}
fn drawBlock(app: *App, block: *const unicode.Block) void {
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
                .font = dvui.Font.theme(.body).withSize(10),
            },
        );
        dvui.label(
            @src(),
            "U+{X:0>4} - U+{X:0>4}",
            .{ block.range.start, block.range.end },
            .{
                .color_text = .fromHex("#aaa"),
                .font = dvui.Font.theme(.body).withSize(8),
                .gravity_y = 0.5,
            },
        );
        hbox.deinit();

        block_btn.drawFocus();

        // possibly focus button
        if (app.state.BlockSelect.block_to_focus) |block_to_focus| {
            if (block_to_focus == block) {
                dvui.focusWidget(block_btn.wd.id, null, null);
                app.state.BlockSelect.block_to_focus = null;
            }
        }
    }
    if (clicked) {
        app.next_state = .{
            .CharacterList = .{
                .block = block,
            },
        };
    }
}
