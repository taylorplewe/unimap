const std = @import("std");
const dvui = @import("dvui");

const App = @import("../App.zig");
const unicode = @import("../unicode/unicode.zig");

var character_font: dvui.Font = undefined;
/// the actual logical UTF-8 bytes that are used to draw the current glyph
var logical: [unicode.PHYSICAL_CHAR_VALUE_ALLOC_SIZE]u8 = undefined;

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
    const num_bytes = std.unicode.utf8Encode(code_point, &logical) catch unreachable;

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

        drawCharacterTooltip(code_point, app, logical[0..num_bytes], &btn);

        // main character
        dvui.labelNoFmt(
            @src(),
            logical[0..num_bytes],
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
                app.state.CharacterList.char_to_focus = null;
            }
        }
    }
    if (clicked) {
        dvui.clipboardTextSet(logical[0..num_bytes]);
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
