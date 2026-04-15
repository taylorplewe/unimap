const std = @import("std");
const dvui = @import("dvui");

const App = @import("../App.zig");
const unicode = @import("../unicode/unicode.zig");

var character_font: dvui.Font = undefined;

pub fn frame(app: *App) void {
    drawUpperBar(app);

    var scroll = dvui.scrollArea(
        @src(),
        .{},
        .{ .expand = .both, .style = .window },
    );
    defer scroll.deinit();

    character_font = dvui.Font.theme(.body)
        .withSize(18)
        .withFamily(App.supported_fonts[app.state.CharacterList.selected_block_index]);

    {
        var flex = dvui.flexbox(@src(), .{}, .{ .expand = .horizontal });
        defer flex.deinit();

        var physical: [unicode.PHYSICAL_CHAR_VALUE_ALLOC_SIZE]u8 = undefined;
        for (app.state.CharacterList.selected_block.range.start..app.state.CharacterList.selected_block.range.end + 1) |code_point| {
            const num_bytes = std.unicode.utf8Encode(@intCast(code_point), &physical) catch unreachable;

            var clicked = false;
            {
                var btn: dvui.ButtonWidget = undefined;
                defer btn.deinit();
                btn.init(
                    @src(),
                    .{ .draw_focus = false },
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

                // tooltip showing HTML, decimal and hex values
                {
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
                            .{unicode.getHtmlNameFromCodePoint(@intCast(code_point))},
                            .{},
                        );
                        cell.deinit();
                        cell = grid.bodyCell(@src(), .colRow(0, 1), .{});
                        dvui.labelNoFmt(
                            @src(),
                            "Logical hex",
                            .{ .ellipsize = false },
                            .{ .color_text = dvui.themeGet().text.opacity(0.5) },
                        );
                        cell.deinit();
                        cell = grid.bodyCell(@src(), .colRow(1, 1), .{});
                        dvui.label(
                            @src(),
                            "0x{x}",
                            .{physical[0..num_bytes]},
                            .{},
                        );
                        cell.deinit();
                    }
                }

                // main character
                dvui.labelNoFmt(
                    @src(),
                    physical[0..num_bytes],
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
            }
            if (clicked) {
                dvui.clipboardTextSet(physical[0..num_bytes]);
                dvui.toast(
                    @src(),
                    .{
                        .timeout = 1_000_000,
                        .message = "Copied!",
                    },
                );
            }
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
        app.state.CharacterList.selected_block.name,
        .{},
        .{ .gravity_x = 0.5, .gravity_y = 0.5 },
    );
}

// /// Like `(std.Io.Reader).takeInt()` or `std.mem.readInt()`, but no reader needed. Generates less machine code.
// /// Unsafe? Very
// inline fn getIntFromDataAtOffs(comptime T: type, data: []u8, offs: usize) T {
//     return std.mem.nativeToBig(T, @as(*T, @ptrCast(@alignCast(data[offs..]))).*);
// }
