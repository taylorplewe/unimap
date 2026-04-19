const std = @import("std");
const dvui = @import("dvui");

const utils = @import("../utils.zig");
const App = @import("../App.zig");
const unicode = @import("../unicode/unicode.zig");

var search_buf: [128]u8 = undefined;
var search_results_len: ?usize = null;
var search_results_buf: [256]SearchResult = undefined;

var go_to_code_point_buf: [6]u8 = undefined;

const CharacterSearchResult = struct {
    code_point: unicode.CodePoint,
    name: []const u8,
    containing_block: *const unicode.Block,
};
const SearchResult = union(enum) {
    block: *const unicode.Block,
    character: CharacterSearchResult,
};

pub fn doFrame(app: *App) void {
    // upper bar with filter thing
    {
        var upper_sticky = dvui.box(
            @src(),
            .{ .dir = .horizontal },
            .{ .expand = .horizontal, .background = true },
        );
        defer upper_sticky.deinit();

        {
            var search_entry = dvui.textEntry(
                @src(),
                .{
                    .placeholder = "Search characters and blocks...",
                    .text = .{ .buffer = &search_buf },
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
                    search_results_len = null;
                } else {
                    search: {
                        search_results_len = 0;
                        for (unicode.blocks) |*block| {
                            if (utils.isNeedleInHaystackCaseInsensitive(block.name, search_query)) {
                                search_results_buf[search_results_len.?] = .{ .block = block };
                                search_results_len.? += 1;
                                if (search_results_len.? == search_results_buf.len) break :search;
                            }
                        }
                        searchCharactersByName(search_query);
                    }
                }
            }

            // forward slash shortcut
            for (dvui.events()) |e| {
                switch (e.evt) {
                    .key => {
                        if (e.evt.key.mod == .none and e.evt.key.code == .slash) {
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
            code_point_entry.deinit();

            if (dvui.button(
                @src(),
                "Go",
                .{ .draw_focus = false },
                .{},
            ) and code_point_entry.textGet().len > 0) {
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

    var scroll = dvui.scrollArea(
        @src(),
        .{},
        .{ .expand = .both, .style = .window },
    );
    defer scroll.deinit();

    if (search_results_len) |_| {
        drawSearchResults(app);
    } else {
        for (unicode.blocks) |*block| {
            drawBlock(app, block);
        }
    }
}

fn drawBlockResult(_: *App, block: *const unicode.Block) void {
    var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
    dvui.labelNoFmt(
        @src(),
        block.name,
        .{},
        .{
            .expand = .horizontal,
            .font = dvui.Font.theme(.body).withSize(10),
            .gravity_y = 0.5,
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
}
fn drawCharacterResult(_: *App, res: *CharacterSearchResult) void {
    // var btn: dvui.ButtonWidget = undefined;
    // defer btn.deinit();
    // btn.init(@src(), .{}, .{ .id_extra = res.code_point, .expand = .horizontal });
    // btn.processEvents();
    // btn.drawBackground();
    // const clicked = btn.clicked();

    var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
    defer hbox.deinit();
    const utf8_encoded = unicode.getUtf8EncodedChar(res.code_point);
    dvui.labelNoFmt(
        @src(),
        utf8_encoded,
        .{},
        .{
            .font = dvui.themeGet().font_body.withSize(18).withFamily(res.containing_block.supported_font),
            .gravity_y = 0.5,
        },
    );
    dvui.labelNoFmt(@src(), res.name, .{}, .{ .gravity_y = 0.5 });
    _ = dvui.spacer(@src(), .{ .expand = .horizontal });
    dvui.label(@src(), "U+{X:0>4}", .{res.code_point}, .{ .gravity_y = 0.5, .color_text = dvui.themeGet().text.opacity(0.4) });
    dvui.labelNoFmt(@src(), res.containing_block.name, .{}, .{ .gravity_y = 0.5 });

    // if (clicked) {
    //     app.next_state = .{
    //         .CharacterList = .{
    //             .block = res.containing_block,
    //             .char_to_focus = res.code_point,
    //         },
    //     };
    // }
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
    }
    if (clicked) {
        app.next_state = .{
            .CharacterList = .{
                .block = block,
            },
        };
    }
}

fn searchCharactersByName(query: []u8) void {
    for (unicode.blocks) |*block| {
        if (unicode.char_names.get(block.name)) |bytes| {
            if (bytes.len == 0) continue;
            const num_header_entries = std.mem.readInt(u16, @ptrCast(bytes[0..]), .little);
            for (0..num_header_entries) |i| {
                const name_addr_addr = (i * @sizeOf(u32)) + @sizeOf(u16);
                const name_addr = std.mem.readInt(u32, @ptrCast(bytes[name_addr_addr..]), .little);
                if (name_addr == 0) continue;
                const name_len = bytes[name_addr];
                const name = bytes[name_addr + 1 .. name_addr + name_len + 1];
                if (utils.isNeedleInHaystackCaseInsensitive(name, query)) {
                    const code_point: unicode.CodePoint = @intCast(i + block.range.start);
                    search_results_buf[search_results_len.?] = .{
                        .character = .{
                            .code_point = code_point,
                            .name = name,
                            .containing_block = block,
                        },
                    };
                    search_results_len.? += 1;
                    if (search_results_len.? == search_results_buf.len) {
                        return;
                    }
                }
            }
        }
    }
}

fn drawSearchResults(app: *App) void {
    const search_results = search_results_buf[0..search_results_len.?];

    // I spent hours figuring this out and I still don't exactly know why--but the scroll info MUST be inside of this struct type,
    // and you pass around the pointer to the scroll_info field, as opposed to instantiating an actual ScrollInfo and passing around
    // a reference to that, or else the scrolling behavior will all be completely messed up.
    const local = struct {
        var scroll_info: dvui.ScrollInfo = .{ .vertical = .given, .horizontal = .none };
    };

    var grid = dvui.grid(
        @src(),
        .numCols(1),
        .{
            .scroll_opts = .{
                .scroll_info = &local.scroll_info,
                .vertical_bar = .auto_overlay,
            },
        },
        .{ .expand = .both, .padding = .all(0) },
    );
    defer grid.deinit();

    const col_width = grid.data().contentRect().w;

    // combine hover state with borders
    const CellStyle = dvui.GridWidget.CellStyle;
    const borders: CellStyle.Borders = .initBox(1, search_results.len, 0, 1);
    var style_hovered: CellStyle.HoveredRow = .{
        .cell_opts = .{
            .background = true,
            .color_fill = dvui.themeGet().color(.control, .fill),
            .color_fill_hover = dvui.themeGet().color(.control, .fill_hover),
            .size = .{ .w = col_width, .h = 48 },
        },
    };
    style_hovered.processEvents(grid);
    const cell_style: CellStyle.Combine(CellStyle.HoveredRow, CellStyle.Borders) = .{
        .style1 = style_hovered,
        .style2 = borders,
    };

    // use virtual scrolling to make scrolling thru hundreds of search results performant
    const scroller: dvui.GridWidget.VirtualScroller = .init(grid, .{ .total_rows = search_results.len, .scroll_info = &local.scroll_info });
    const first = scroller.startRow();
    const last = scroller.endRow(); // Note that endRow is exclusive, meaning it can be used as a slice end index.
    for (first..last) |num| {
        const cell_num: dvui.GridWidget.Cell = .colRow(0, num);
        {
            var cell = grid.bodyCell(@src(), cell_num, cell_style.cellOptions(cell_num));
            defer cell.deinit();
            const clicked = dvui.clicked(&cell.wd, .{});
            switch (search_results[num]) {
                .block => {
                    drawBlockResult(app, search_results[num].block);
                    if (clicked) {
                        app.next_state = .{
                            .CharacterList = .{ .block = search_results[num].block },
                        };
                    }
                },
                .character => {
                    drawCharacterResult(app, &search_results[num].character);
                    if (clicked) {
                        app.next_state = .{
                            .CharacterList = .{
                                .block = search_results[num].character.containing_block,
                                .char_to_focus = search_results[num].character.code_point,
                            },
                        };
                    }
                },
            }
        }
    }

    // // const animator = dvui.animate(
    // //     @src(),
    // //     .{
    // //         .duration = 150_000,
    // //         .easing = dvui.easing.inOutQuad,
    // //         .kind = .alpha,
    // //     },
    // //     .{
    // //         .expand = .both,
    // //     },
    // // );
    // // defer animator.deinit();

    // // var floating_window_rect: dvui.Rect = .cast(dvui.windowRect().insetAll(16));
    // // var floating_window = dvui.floatingWindow(@src(), .{
    // //     .resize = .none,
    // //     .rect = &floating_window_rect,
    // //     .stay_above_parent_window = true,
    // // }, .{});
    // // defer floating_window.deinit();
}
