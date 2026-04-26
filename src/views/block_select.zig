const std = @import("std");
const dvui = @import("dvui");

const utils = @import("../utils.zig");
const App = @import("../App.zig");
const unicode = @import("../unicode/unicode.zig");
const search = @import("../search.zig");
const search_window = @import("components/search_window.zig");

var should_focus_modal_search_bar = false;

var go_to_code_point_buf: [6]u8 = undefined;

pub fn doFrame(app: *App) void {
    drawUpperSticky(app);

    var scroll = dvui.scrollArea(
        @src(),
        .{},
        .{ .expand = .both, .style = .window },
    );
    defer scroll.deinit();
    for (unicode.blocks) |*block| {
        drawBlock(app, block);
    }
    if (search.results_len) |_| {
        search_window.drawSearchWindow(app, should_focus_modal_search_bar);
        should_focus_modal_search_bar = false;
    }
}
fn drawUpperSticky(app: *App) void {
    var upper_sticky = dvui.box(
        @src(),
        .{ .dir = .horizontal },
        .{ .expand = .horizontal, .background = true },
    );
    defer upper_sticky.deinit();

    if (dvui.buttonIcon(@src(), "about", dvui.entypo.info_with_circle, .{ .draw_focus = false }, .{}, .{ .gravity_y = 0.5 })) {
        dvui.dialog(@src(), .{}, .{ .message = "", .displayFn = infoDialogDisplayFn });
    }

    if (search.results_len == null) {
        var search_entry = dvui.textEntry(
            @src(),
            .{
                .placeholder = "Search characters and blocks...",
                .text = .{ .buffer = &search.query_buf },
            },
            .{
                .min_size_content = .sizeM(26, 1),
                .gravity_x = 0.5,
            },
        );
        defer search_entry.deinit();

        if (search_entry.text_changed) {
            const search_query = search_entry.textGet();
            if (search_query.len == 0) {
                search.results_len = null;
            } else {
                search: {
                    search.results_len = 0;
                    should_focus_modal_search_bar = true;
                    for (unicode.blocks) |*block| {
                        if (utils.isNeedleInHaystack(block.name, search_query, false)) {
                            search.results_buf[search.results_len.?] = .{ .block = block };
                            search.results_len.? += 1;
                            if (search.results_len.? == search.results_buf.len) break :search;
                        }
                    }
                    search.searchCharactersByName(search_query);
                }
            }
        }

        // forward slash shortcut
        for (dvui.events()) |e| {
            switch (e.evt) {
                .key => {
                    if ((e.evt.key.mod == .none and e.evt.key.code == .slash) or (e.evt.key.mod.control() and e.evt.key.code == .k)) {
                        dvui.currentWindow().focusWidget(search_entry.wd.id, null, null);
                    }
                },
                else => break,
            }
        }
    }

    _ = dvui.spacer(@src(), .{ .expand = .horizontal });

    // go to code point
    {
        var should_go_to_point = false;

        dvui.labelNoFmt(
            @src(),
            "Go to U+",
            .{ .ellipsize = false },
            .{
                .gravity_y = 0.5,
                .padding = .{
                    .x = dvui.LabelWidget.defaults.padding.?.x,
                    .y = dvui.LabelWidget.defaults.padding.?.y,
                    .w = 0,
                    .h = dvui.LabelWidget.defaults.padding.?.h,
                },
            },
        );
        var code_point_entry = dvui.textEntry(
            @src(),
            .{ .placeholder = "000000", .text = .{ .buffer = &go_to_code_point_buf } },
            .{ .max_size_content = .sizeM(6, 1) },
        );
        const code_point_text = code_point_entry.textGet();
        for (dvui.events()) |e| {
            switch (e.evt) {
                .key => |key| {
                    if ((key.code == .enter or key.code == .kp_enter) and key.action == .down) {
                        should_go_to_point = true;
                    }
                },
                else => {},
            }
        }
        code_point_entry.deinit();

        if (dvui.button(
            @src(),
            "Go",
            .{ .draw_focus = false },
            .{},
        ) or should_go_to_point) {
            if (code_point_entry.textGet().len > 0) {
                if (std.fmt.parseInt(unicode.CodePoint, code_point_text, 16)) |code_point| {
                    if (unicode.getBlockThatContainsCodePoint(code_point)) |block| {
                        app.next_state = .{
                            .CharacterList = .{
                                .block = block,
                                .char_to_focus = code_point,
                            },
                        };
                        @memset(&go_to_code_point_buf, 0);
                    }
                } else |_| {} // invalid input
            }
        }
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
                app.next_state.BlockSelect.block_to_focus = null;
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
