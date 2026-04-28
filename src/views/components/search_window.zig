const std = @import("std");
const dvui = @import("dvui");

const App = @import("../../App.zig");
const search = @import("../../search.zig");
const unicode = @import("../../unicode/unicode.zig");
const utils = @import("../../utils.zig");

pub fn doFrame(app: *App) void {
    const animator = dvui.animate(
        @src(),
        .{
            .duration = 150_000,
            .easing = dvui.easing.inOutQuad,
            .kind = .alpha,
        },
        .{
            .expand = .both,
        },
    );
    defer animator.deinit();

    var floating_window_rect: dvui.Rect = .cast(dvui.windowRect().insetAll(32));
    var floating_window = dvui.floatingWindow(@src(), .{
        .resize = .none,
        .rect = &floating_window_rect,
        .stay_above_parent_window = true,
        .modal = true,
    }, .{
        .box_shadow = .{
            .fade = 23,
            .alpha = 0.3,
            .offset = .{ .x = 0, .y = 4 },
        },
        .color_text = .fromHex("#000f"), // drop shadow color == text color
    });
    defer floating_window.deinit();

    // search entry & close button at top
    {
        var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer hbox.deinit();
        {
            var search_entry = dvui.textEntry(
                @src(),
                .{
                    .text = .{ .buffer = &search.query_buf },
                    .placeholder = "Search blocks & characters...",
                },
                .{ .expand = .horizontal },
            );
            defer search_entry.deinit();
            if (search_entry.text_changed) {
                const search_query = search_entry.textGet();
                if (search_query.len > 0)
                    search.searchAll(search_query)
                else
                    search.clearSearchResults();
            }
            if (search.should_focus_search_bar) {
                dvui.focusWidget(search_entry.wd.id, floating_window.wd.id, null);
                search.should_focus_search_bar = false;
            }

            // escape to close window
            for (dvui.events()) |e| {
                switch (e.evt) {
                    .key => if (e.evt.key.code == .escape) {
                        search_entry.len = 0;
                        search.clearSearchResultsAndCloseWindow();
                    },
                    else => {},
                }
            }
        }

        const mSize = dvui.Font.theme(.body).sizeM(1, 1);
        if (dvui.buttonIcon(
            @src(),
            "close search window",
            dvui.entypo.cross,
            .{},
            .{},
            .{
                .border = .all(1),
                .min_size_content = .{
                    .w = mSize.w + 8,
                    .h = mSize.w + 8,
                },
                .margin = .{
                    .x = 0,
                    .y = 4,
                    .w = 4,
                    .h = 0,
                },
            },
        )) {
            search.clearSearchResultsAndCloseWindow();
        }
    }

    if (search.results().len == 0) {
        const HelpText = struct {
            text_layout: *dvui.TextLayoutWidget,
            fn init(src: std.builtin.SourceLocation) @This() {
                return .{
                    .text_layout = dvui.textLayout(
                        src,
                        .{ .break_lines = false },
                        .{
                            .gravity_x = 0.5,
                            .gravity_y = 0.5,
                            .background = false,
                            .color_text = dvui.themeGet().text.opacity(0.5),
                        },
                    ),
                };
            }
            fn deinit(self: *@This()) void {
                self.text_layout.deinit();
            }
            fn dimText(self: *@This(), text: []const u8) void {
                self.text_layout.addText(text, .{});
            }
            fn brightText(self: *@This(), text: []const u8) void {
                self.text_layout.addText(text, .{ .color_text = dvui.themeGet().text });
            }
            fn brightTextList(self: *@This(), texts: []const []const u8) void {
                for (texts, 0..) |text, i| {
                    if (i > 0) {
                        self.dimText(", ");
                    }
                    self.brightText(text);
                }
            }
        };

        var help_text: HelpText = .init(@src());
        defer help_text.deinit();
        if (search.query_readonly.len == 0) {
            help_text.dimText("☞ Search Unicode character names: ");
            help_text.brightTextList(&.{ "floral", "confused face", "with cedilla" });
            help_text.dimText("\n☞ Search Unicode blocks: ");
            help_text.brightTextList(&.{ "emoticons", "braille" });
            help_text.dimText("\n☞ Go to code point: ");
            help_text.brightTextList(&.{ "30db", "1f643" });
        } else {
            help_text.dimText("No results for ");
            help_text.brightText(search.query_readonly);
        }
        return;
    }

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
    const borders: CellStyle.Borders = .initBox(1, search.results().len, 0, 1);
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
    const scroller: dvui.GridWidget.VirtualScroller = .init(grid, .{ .total_rows = search.results().len, .scroll_info = &local.scroll_info });
    const first = scroller.startRow();
    const last = scroller.endRow(); // Note that endRow is exclusive, meaning it can be used as a slice end index.
    result_loop: for (first..last) |num| {
        const cell_num: dvui.GridWidget.Cell = .colRow(0, num);
        {
            var cell = grid.bodyCell(@src(), cell_num, cell_style.cellOptions(cell_num));
            defer cell.deinit();
            const clicked = dvui.clicked(&cell.wd, .{});
            switch (search.results()[num]) {
                .code_point => |res| {
                    drawGoToCodePointResult(res);
                    if (clicked) {
                        app.next_state = .{
                            .CharacterList = .{ .block = res.containing_block, .char_to_focus = res.code_point },
                        };
                    }
                },
                .block => |block| {
                    drawBlockResult(block);
                    if (clicked) {
                        app.next_state = .{
                            .CharacterList = .{ .block = block },
                        };
                    }
                },
                .character => |res| {
                    drawCharacterResult(res);
                    if (clicked) {
                        app.next_state = .{
                            .CharacterList = .{
                                .block = res.containing_block,
                                .char_to_focus = res.code_point,
                            },
                        };
                    }
                },
            }
            if (clicked) {
                search.clearSearchResultsAndCloseWindow();
                break :result_loop;
            }
        }
    }
}
fn drawGoToCodePointResult(res: search.CharacterSearchResult) void {
    dvui.icon(@src(), "go to code point", dvui.entypo.forward, .{}, .{ .gravity_y = 0.5, .margin = .{ .x = 8, .y = 0, .w = 0, .h = 0 } });
    {
        var text_layout = dvui.textLayout(@src(), .{ .break_lines = false }, .{ .gravity_y = 0.5, .background = false });
        defer text_layout.deinit();
        text_layout.addText("Go to code point ", .{ .color_text = dvui.themeGet().text.opacity(0.4), .gravity_y = 0.5 });
        text_layout.format("U+{X:0>4} ", .{res.code_point}, .{ .gravity_y = 0.5 });
    }

    const utf8_encoded = unicode.getUtf8EncodedChar(res.code_point);
    dvui.labelNoFmt(@src(), utf8_encoded, .{}, .{ .font = dvui.themeGet().font_body.withSize(18).withFamily(res.containing_block.supported_font), .gravity_y = 0.5 });
    if (res.name.len > 0) {
        dvui.label(@src(), "\"{s}\"", .{res.name}, .{ .color_text = dvui.themeGet().text.opacity(0.4), .gravity_y = 0.5 });
    }
}
fn drawBlockResult(block: *const unicode.Block) void {
    var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .both });
    dvui.labelNoFmt(
        @src(),
        "Block",
        .{},
        .{
            .font = dvui.Font.theme(.body).withSize(8),
            .color_text = dvui.themeGet().text.opacity(0.4),
            .gravity_y = 0.5,
        },
    );
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
            .color_text = dvui.themeGet().text.opacity(0.4),
            .gravity_y = 0.5,
        },
    );
    hbox.deinit();
}
fn drawCharacterResult(res: search.CharacterSearchResult) void {
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
}
