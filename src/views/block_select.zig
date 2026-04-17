const std = @import("std");
const dvui = @import("dvui");

const utils = @import("../utils.zig");
const App = @import("../App.zig");
const unicode = @import("../unicode/unicode.zig");
var filtered_blocks: [400]*const unicode.Block = undefined;
var filtered_blocks_len: ?usize = null;
var blocks_search_entry_buf: [256]u8 = undefined;

var character_results_buf: [2048]CharacterSearchResult = undefined;
var character_results_len: ?usize = null;

pub fn frame(app: *App) void {
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
                .{ .placeholder = "Search characters..." },
                .{},
            );
            defer search_entry.deinit();

            if (search_entry.text_changed) {
                const search_query = search_entry.textGet();
                if (search_query.len == 0) {
                    character_results_len = null;
                } else {
                    searchCharactersByName(search_query);
                    std.debug.print("num of results: {d}\n", .{character_results_len.?});
                    for (character_results_buf[0..character_results_len.?]) |res| {
                        std.debug.print(" U+{X:0>6} - {s} - {s}\n", .{ res.code_point, res.name, res.containing_block.name });
                    }
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
    }

    var scroll = dvui.scrollArea(
        @src(),
        .{},
        .{ .expand = .both, .style = .window },
    );
    defer scroll.deinit();

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
            .CharacterList = block,
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
