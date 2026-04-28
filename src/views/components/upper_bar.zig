const dvui = @import("dvui");

const App = @import("../../App.zig");
const search_button = @import("search_button.zig");

pub fn doFrame(app: *App) void {
    var upper_sticky = dvui.box(
        @src(),
        .{ .dir = .horizontal },
        .{ .expand = .horizontal, .background = true },
    );
    defer upper_sticky.deinit();

    switch (app.state) {
        .BlockSelect => {
            if (dvui.buttonIcon(
                @src(),
                "about",
                dvui.entypo.info_with_circle,
                .{ .draw_focus = false },
                .{},
                .{ .gravity_y = 0.5 },
            )) {
                dvui.dialog(@src(), .{}, .{ .message = "", .displayFn = infoDialogDisplayFn });
            }
        },
        .CharacterList => {
            var should_go_back = false;
            for (dvui.events()) |e| {
                switch (e.evt) {
                    .mouse => |mouse| {
                        if (mouse.button == .four) should_go_back = true;
                    },
                    else => {},
                }
            }
            if (dvui.buttonLabelAndIcon(
                @src(),
                .{
                    .icon_first = true,
                    .label = "Back to blocks",
                    .tvg_bytes = dvui.entypo.arrow_bold_left,
                    .button_opts = .{},
                },
                .{
                    .min_size_content = .{ .w = 128 },
                },
            ) or should_go_back) {
                app.next_state = .{ .BlockSelect = .{ .block_to_focus = app.state.CharacterList.block } };
            }

            dvui.labelNoFmt(
                @src(),
                app.state.CharacterList.block.name,
                .{},
                .{ .gravity_x = 0.5, .gravity_y = 0.5 },
            );
        },
    }

    _ = dvui.spacer(@src(), .{ .expand = .horizontal });

    search_button.doFrame();
}
/// Simplified version of the default `dialogDisplay()` from `dvui.zig`
fn infoDialogDisplayFn(id: dvui.Id) !void {
    var win = dvui.floatingWindow(
        @src(),
        .{ .modal = false },
        .{ .role = .dialog, .id_extra = id.asUsize() },
    );
    defer win.deinit();

    var header_openflag = true;
    win.dragAreaSet(dvui.windowHeader("Unimap", "", &header_openflag));
    if (!header_openflag) {
        dvui.dialogRemove(id);
        return;
    }

    {
        // Add the buttons at the bottom first, so that they are guaranteed to be shown
        var hbox = dvui.box(
            @src(),
            .{ .dir = .horizontal },
            .{ .gravity_x = 0.5, .gravity_y = 1.0 },
        );
        defer hbox.deinit();

        var ok_data: dvui.WidgetData = undefined;
        if (dvui.button(@src(), "Close", .{}, .{ .data_out = &ok_data })) {
            dvui.dialogRemove(id);
            return;
        }
        dvui.focusWidget(ok_data.id, null, null);
    }

    // Now add the scroll area which will get the remaining space
    var scroll = dvui.scrollArea(@src(), .{}, .{ .expand = .both, .style = .window });
    var tl = dvui.textLayout(
        @src(),
        .{},
        .{
            .background = false,
            .gravity_x = 0.5,
        },
    );
    tl.addText("© 2026 Taylor Plewe", .{});
    tl.deinit();
    dvui.link(@src(), .{ .url = "https://github.com/taylorplewe/unimap" }, .{});
    scroll.deinit();
}
