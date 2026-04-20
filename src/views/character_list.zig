const std = @import("std");
const dvui = @import("dvui");

const App = @import("../App.zig");
const unicode = @import("../unicode/unicode.zig");

var character_font: dvui.Font = undefined;

pub fn doFrame(app: *App) void {
    drawUpperBar(app);

    var scroll = dvui.scrollArea(
        @src(),
        .{},
        .{ .expand = .both, .style = .window },
    );
    defer scroll.deinit();

    character_font = dvui.Font.theme(.body)
        .withSize(18)
        .withFamily(app.state.CharacterList.block.supported_font);

    {
        var flex = dvui.flexbox(@src(), .{}, .{ .expand = .horizontal });
        defer flex.deinit();

        for (app.state.CharacterList.block.range.start..app.state.CharacterList.block.range.end + 1) |code_point| {
            drawCharacterButton(@intCast(code_point), app);
        }

        // see the comment above the `local` struct in `block_select.zig` for why this exists
        // const local = struct {
        //     var scroll_info: dvui.ScrollInfo = .{ .vertical = .given, .horizontal = .none };
        // };

        // const NUM_COLUMNS = 10;
        // const num_rows: usize = @intCast(((app.state.CharacterList.block.range.end - app.state.CharacterList.block.range.start) + 1) / NUM_COLUMNS);
        // var grid = dvui.grid(
        //     @src(),
        //     .numCols(NUM_COLUMNS),
        //     .{
        //         .scroll_opts = .{
        //             .scroll_info = &local.scroll_info,
        //             .vertical_bar = .auto_overlay,
        //         },
        //     },
        //     .{ .expand = .both, .padding = .all(0) },
        // );
        // defer grid.deinit();

        // const col_width = grid.data().contentRect().w / NUM_COLUMNS;

        // // use virtual scrolling to make scrolling thru hundreds of search results performant
        // const scroller: dvui.GridWidget.VirtualScroller = .init(grid, .{
        //     .total_rows = num_rows,
        //     .scroll_info = &local.scroll_info,
        // });

        // const first = scroller.startRow();
        // const last = scroller.endRow(); // Note that endRow is exclusive, meaning it can be used as a slice end index.
        // outer_loop: for (first..last) |row| {
        //     for (0..NUM_COLUMNS) |col| {
        //         const index = (row * NUM_COLUMNS) + col;
        //         if (index >= app.state.CharacterList.block.range.end) break :outer_loop;
        //         // const code_point = app.state.CharacterList.block.range.start + @as(unicode.CodePoint, @intCast(index));

        //         const cell_num: dvui.GridWidget.Cell = .colRow(col, row);
        //         {
        //             var cell = grid.bodyCell(@src(), cell_num, .{ .size = .all(col_width) });
        //             defer cell.deinit();
        //             dvui.labelNoFmt(@src(), "test", .{}, .{}); // NOTE: this performs great
        //             // drawCharacterButton(@intCast(code_point), app);
        //         }
        //     }
        // }
    }
}

/// Draw the upper bar with the back button and possibly other future controls
/// Returns `true` if the back button was clicked
fn drawUpperBar(app: *App) void {
    var upper_sticky = dvui.box(
        @src(),
        .{ .dir = .horizontal },
        .{ .expand = .horizontal, .background = true },
    );
    defer upper_sticky.deinit();

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
    )) {
        app.next_state = .BlockSelect;
    }

    dvui.labelNoFmt(
        @src(),
        app.state.CharacterList.block.name,
        .{},
        .{ .gravity_x = 0.5, .gravity_y = 0.5 },
    );
}

inline fn drawCharacterButton(code_point: unicode.CodePoint, app: *App) void {
    const utf8_encoded = unicode.getUtf8EncodedChar(code_point);

    var clicked = false;
    {
        var btn: dvui.ButtonWidget = undefined;
        defer btn.deinit();
        btn.init(
            @src(),
            .{},
            .{
                .id_extra = code_point,
                .padding = .all(2),
                .min_size_content = .{ .w = 64, .h = 64 },
                .max_size_content = .{ .w = 64, .h = 64 },
            },
        );
        btn.processEvents();
        btn.drawBackground();
        clicked = btn.clicked();

        drawCharacterTooltip(code_point, app, utf8_encoded, &btn);

        // main character
        dvui.labelNoFmt(
            @src(),
            utf8_encoded,
            .{ .ellipsize = false },
            .{
                .font = character_font,
                .gravity_x = 0.5,
                .gravity_y = 0.5,
            },
        );

        // Unicode code point (e.g. "U+0000")
        dvui.label(
            @src(),
            "U+{X:0>4}",
            .{code_point},
            .{
                .font = dvui.Font.theme(.body).withSize(8),
                .gravity_x = 0.5,
                .gravity_y = 1.0,
                .padding = .all(0),
                .color_text = dvui.currentWindow().theme.text.opacity(0.4),
            },
        );
        btn.drawFocus();

        // got here from clicking a search result?
        if (app.state.CharacterList.char_to_focus) |char_to_focus| {
            if (char_to_focus == code_point) {
                dvui.currentWindow().focusWidget(btn.wd.id, null, null);
                btn.init_options.draw_focus = true;
                app.next_state.CharacterList.char_to_focus = null;
            }
        }
    }
    if (clicked) {
        dvui.clipboardTextSet(utf8_encoded);
        dvui.toast(
            @src(),
            .{
                .timeout = 1_000_000,
                .message = "Copied!",
            },
        );
    }
}

/// draw the tooltip showing HTML, decimal and hex values for a given character button
inline fn drawCharacterTooltip(
    code_point: unicode.CodePoint,
    app: *App,
    logical_value: []u8,
    btn: *dvui.ButtonWidget,
) void {
    var tooltip: dvui.FloatingTooltipWidget = undefined;
    defer tooltip.deinit();
    tooltip.init(
        @src(),
        .{
            .active_rect = btn.wd.borderRectScale().r,
            .delay = 1_000_000,
        },
        .{ .role = .tooltip },
    );
    if (tooltip.shown()) {
        const char_name = unicode.getCharName(code_point, app.state.CharacterList.block);
        if (char_name != null) {
            dvui.label(@src(), "{s}", .{char_name.?}, .{});
        } else {
            dvui.labelNoFmt(
                @src(),
                "<unnamed>",
                .{},
                .{ .color_text = dvui.themeGet().text.opacity(0.4) },
            );
        }

        var grid: dvui.GridWidget = undefined;
        defer grid.deinit();
        grid.init(@src(), .numCols(2), .{}, .{});

        var cell: *dvui.BoxWidget = undefined;
        cell = grid.bodyCell(@src(), .colRow(0, 0), .{});
        dvui.labelNoFmt(
            @src(),
            "HTML",
            .{ .ellipsize = false },
            .{ .color_text = dvui.themeGet().text.opacity(0.5) },
        );
        cell.deinit();
        cell = grid.bodyCell(@src(), .colRow(1, 0), .{});
        dvui.label(
            @src(),
            "{s}",
            .{unicode.getHtmlNameFromCodePoint(code_point)},
            .{},
        );
        cell.deinit();
        cell = grid.bodyCell(@src(), .colRow(0, 1), .{});
        dvui.labelNoFmt(
            @src(),
            "UTF-8 hex",
            .{ .ellipsize = false },
            .{ .color_text = dvui.themeGet().text.opacity(0.5) },
        );
        cell.deinit();
        cell = grid.bodyCell(@src(), .colRow(1, 1), .{});
        dvui.label(
            @src(),
            "0x{x}",
            .{logical_value},
            .{},
        );
        cell.deinit();
    }
}

// /// Like `(std.Io.Reader).takeInt()` or `std.mem.readInt()`, but no reader needed. Generates less machine code.
// /// Unsafe? Very
// inline fn getIntFromDataAtOffs(comptime T: type, data: []u8, offs: usize) T {
//     return std.mem.nativeToBig(T, @as(*T, @ptrCast(@alignCast(data[offs..]))).*);
// }
