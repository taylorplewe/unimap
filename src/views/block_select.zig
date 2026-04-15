const dvui = @import("dvui");

const utils = @import("../utils.zig");
const App = @import("../App.zig");
const unicode = @import("../unicode/unicode.zig");
var filtered_blocks: [400]*const unicode.Block = undefined;
var filtered_blocks_len: ?usize = null;
var search_entry_buf: [256]u8 = undefined;

pub fn frame(app: *App) void {
    // upper bar with filter thing
    {
        var upper_sticky = dvui.box(
            @src(),
            .{ .dir = .horizontal },
            .{ .expand = .horizontal, .background = true },
        );
        defer upper_sticky.deinit();

        var search_entry = dvui.textEntry(
            @src(),
            .{ .placeholder = "Filter blocks...", .text = .{ .buffer = &search_entry_buf } },
            .{ .gravity_x = 1.0 },
        );
        defer search_entry.deinit();

        if (search_entry.text_changed) {
            const search_query = search_entry.textGet();
            if (search_query.len == 0) {
                filtered_blocks_len = null;
            } else {
                filtered_blocks_len = 0;
                for (App.blocks) |*block| {
                    // if (std.mem.containsAtLeast(u8, block.name, 1, search_query)) {
                    if (utils.isNeedleInHaystackCaseInsensitive(block.name, search_query)) {
                        filtered_blocks[filtered_blocks_len.?] = block;
                        filtered_blocks_len.? += 1;
                    }
                }
            }
        }
    }

    var scroll = dvui.scrollArea(
        @src(),
        .{},
        .{ .expand = .both, .style = .window },
    );
    defer scroll.deinit();

    if (filtered_blocks_len) |len| {
        for (filtered_blocks[0..len], 0..) |block, i| {
            drawBlock(app, block, i);
        }
    } else {
        for (App.blocks, 0..) |*block, i| {
            drawBlock(app, block, i);
        }
    }
}

fn drawBlock(app: *App, block: *const unicode.Block, i: usize) void {
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
                .selected_block = block,
                .selected_block_index = i,
            },
        };
    }
}
