const std = @import("std");
const dvui = @import("dvui");

const utils = @import("../utils.zig");
const App = @import("../App.zig");
const unicode = @import("../unicode/unicode.zig");
var filtered_blocks: [400]*const unicode.Block = undefined;
var filtered_blocks_len: ?usize = null;
var blocks_search_entry_buf: [256]u8 = undefined;

var character_results_buf: [256]CharacterSearchResult = undefined;
var character_results_len: ?usize = null;
var character_search_buf: [256]u8 = undefined;

var go_to_code_point_buf: [6]u8 = undefined;

pub fn doFrame(app: *App) void {
    // upper bar with filter thing
    {
        var upper_sticky = dvui.box(
            @src(),
            .{ .dir = .horizontal },
            .{ .expand = .horizontal, .background = true },
        );
        defer upper_sticky.deinit();

        // chars search input
        {
            var search_entry = dvui.textEntry(
                @src(),
                .{ .placeholder = "Search characters...", .text = .{ .buffer = &character_search_buf } },
                .{},
            );
            defer search_entry.deinit();

            if (search_entry.text_changed) {
                const search_query = search_entry.textGet();
                if (search_query.len == 0) {
                    character_results_len = null;
                } else {
                    searchCharactersByName(search_query);
                    // std.debug.print("num of results: {d}\n", .{character_results_len.?});
                    // for (character_results_buf[0..character_results_len.?]) |res| {
                    //     std.debug.print(" U+{X:0>6} - {s} - {s}\n", .{ res.code_point, res.name, res.containing_block.name });
                    // }
                }
            }
        }

        // blocks search input
        {
            var search_entry = dvui.textEntry(
                @src(),
                .{ .placeholder = "Filter blocks...", .text = .{ .buffer = &blocks_search_entry_buf } },
                .{},
            );
            defer search_entry.deinit();

            if (search_entry.text_changed) {
                const search_query = search_entry.textGet();
                if (search_query.len == 0) {
                    filtered_blocks_len = null;
                } else {
                    filtered_blocks_len = 0;
                    for (unicode.blocks) |*block| {
                        // if (std.mem.containsAtLeast(u8, block.name, 1, search_query)) {
                        if (utils.isNeedleInHaystackCaseInsensitive(block.name, search_query)) {
                            filtered_blocks[filtered_blocks_len.?] = block;
                            filtered_blocks_len.? += 1;
                        }
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
                "Go to code point U+",
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

    if (character_results_len) |len| {
        var scroll_info: dvui.ScrollInfo = .{ .vertical = .auto, .horizontal = .none };
        var grid = dvui.grid(
            @src(),
            .numCols(1),
            .{ .scroll_opts = .{ .scroll_info = &scroll_info } },
            .{ .expand = .both, .background = true },
        );
        defer grid.deinit();
        const scroller: dvui.GridWidget.VirtualScroller = .init(grid, .{
            .total_rows = len,
            .scroll_info = &scroll_info,
        });
        const first = scroller.startRow();
        const last = scroller.endRow();
        for (first..last) |i| {
            var cell = grid.bodyCell(
                @src(),
                .colRow(0, i),
                .{ .size = .{ .w = grid.data().contentRect().w - dvui.GridWidget.scrollbar_padding_defaults.w } },
            );
            defer cell.deinit();
            drawCharacterResult(app, &character_results_buf[i]);
        }
        // for (character_results_buf[0..len]) |*res| {
        //     drawCharacterResult(app, res);
        // }
    } else {
        if (filtered_blocks_len) |len| {
            for (filtered_blocks[0..len]) |block| {
                drawBlock(app, block);
            }
        } else {
            for (unicode.blocks) |*block| {
                drawBlock(app, block);
            }
        }
    }
}

fn drawCharacterResult(app: *App, res: *CharacterSearchResult) void {
    var btn: dvui.ButtonWidget = undefined;
    defer btn.deinit();
    btn.init(@src(), .{}, .{ .id_extra = res.code_point, .expand = .horizontal });
    btn.processEvents();
    btn.drawBackground();
    const clicked = btn.clicked();

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

    if (clicked) {
        app.next_state = .{
            .CharacterList = .{
                .block = res.containing_block,
                .char_to_focus = res.code_point,
            },
        };
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
    }
    if (clicked) {
        app.next_state = .{
            .CharacterList = .{
                .block = block,
            },
        };
    }
}

const CharacterSearchResult = struct {
    code_point: unicode.CodePoint,
    name: []const u8,
    containing_block: *const unicode.Block,
};
fn searchCharactersByName(query: []u8) void {
    character_results_len = 0;
    block_loop: for (unicode.blocks) |*block| {
        if (unicode.char_names.get(block.name)) |bytes| {
            if (bytes.len == 0) continue :block_loop;
            const num_header_entries = std.mem.readInt(u16, @ptrCast(bytes[0..]), .little);
            for (0..num_header_entries) |i| {
                const name_addr_addr = (i * @sizeOf(u32)) + @sizeOf(u16);
                const name_addr = std.mem.readInt(u32, @ptrCast(bytes[name_addr_addr..]), .little);
                if (name_addr == 0) continue;
                const name_len = bytes[name_addr];
                const name = bytes[name_addr + 1 .. name_addr + name_len + 1];
                if (utils.isNeedleInHaystackCaseInsensitive(name, query)) {
                    const code_point: unicode.CodePoint = @intCast(i + block.range.start);
                    character_results_buf[character_results_len.?] = .{
                        .code_point = code_point,
                        .name = name,
                        .containing_block = block,
                    };
                    character_results_len.? += 1;
                    if (character_results_len.? == character_results_buf.len) {
                        break :block_loop;
                    }
                }
            }
        }
    }
}
