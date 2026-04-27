const std = @import("std");
const dvui = @import("dvui");

const utils = @import("../utils.zig");
const App = @import("../App.zig");
const unicode = @import("../unicode/unicode.zig");
const search = @import("../search.zig");
const search_button = @import("components/search_button.zig");

var go_to_code_point_buf: [6]u8 = undefined;

pub fn doFrame(app: *App) void {
    for (unicode.blocks) |*block| {
        drawBlock(app, block);
    }
}
// fn drawUpperSticky(app: *App) void {
//     var upper_sticky = dvui.box(
//         @src(),
//         .{ .dir = .horizontal },
//         .{ .expand = .horizontal, .background = true },
//     );
//     defer upper_sticky.deinit();

//     if (dvui.buttonIcon(@src(), "about", dvui.entypo.info_with_circle, .{ .draw_focus = false }, .{}, .{ .gravity_y = 0.5 })) {
//         dvui.dialog(@src(), .{}, .{ .message = "", .displayFn = infoDialogDisplayFn });
//     }

//     _ = dvui.spacer(@src(), .{ .expand = .horizontal });

//     // go to code point
//     {
//         var should_go_to_point = false;

//         dvui.labelNoFmt(
//             @src(),
//             "Go to U+",
//             .{ .ellipsize = false },
//             .{
//                 .gravity_y = 0.5,
//                 .padding = .{
//                     .x = dvui.LabelWidget.defaults.padding.?.x,
//                     .y = dvui.LabelWidget.defaults.padding.?.y,
//                     .w = 0,
//                     .h = dvui.LabelWidget.defaults.padding.?.h,
//                 },
//             },
//         );
//         var code_point_entry = dvui.textEntry(
//             @src(),
//             .{ .placeholder = "000000", .text = .{ .buffer = &go_to_code_point_buf } },
//             .{ .max_size_content = .sizeM(6, 1) },
//         );
//         const code_point_text = code_point_entry.textGet();
//         for (dvui.events()) |e| {
//             switch (e.evt) {
//                 .key => |key| {
//                     if ((key.code == .enter or key.code == .kp_enter) and key.action == .down) {
//                         should_go_to_point = true;
//                     }
//                 },
//                 else => {},
//             }
//         }
//         code_point_entry.deinit();

//         if (dvui.button(
//             @src(),
//             "Go",
//             .{ .draw_focus = false },
//             .{},
//         ) or should_go_to_point) {
//             if (code_point_entry.textGet().len > 0) {
//                 if (std.fmt.parseInt(unicode.CodePoint, code_point_text, 16)) |code_point| {
//                     if (unicode.getBlockThatContainsCodePoint(code_point)) |block| {
//                         app.next_state = .{
//                             .CharacterList = .{
//                                 .block = block,
//                                 .char_to_focus = code_point,
//                             },
//                         };
//                         @memset(&go_to_code_point_buf, 0);
//                     }
//                 } else |_| {} // invalid input
//             }
//         }
//     }

//     search_button.doFrame();
// }
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
