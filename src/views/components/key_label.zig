const std = @import("std");
const dvui = @import("dvui");

const SMALL_FONT_SIZE = 6;

var uid: usize = 0;
pub fn drawKey(text: []const u8, color: dvui.Color) void {
    const small_font = dvui.Font.theme(.body).withSize(SMALL_FONT_SIZE);
    dvui.labelNoFmt(@src(), text, .{}, .{
        .background = true,
        .corner_radius = .all(4),
        .border = .{
            .x = 1,
            .y = 1,
            .w = 1,
            .h = 2,
        },
        .padding = .all(2),
        .margin = .all(0),
        .font = small_font,
        .color_border = color,
        .color_text = color,
        .gravity_y = 0.5,
        .id_extra = getAndIncrementUid(),
    });
}

pub const KeyCombo = []const []const u8;
pub fn list(src: std.builtin.SourceLocation, combos: []const KeyCombo, color: dvui.Color) void {
    const text_options = dvui.Options{
        .gravity_y = 0.5,
        .color_text = color,
        .margin = .all(2),
        .padding = .all(0),
    };
    for (combos, 0..) |combo, i| {
        if (i > 0) {
            dvui.labelNoFmt(
                src,
                ", ",
                .{},
                text_options.override(.{ .id_extra = getAndIncrementUid() }),
            );
        }
        for (combo, 0..) |text, j| {
            if (j > 0) {
                dvui.labelNoFmt(
                    src,
                    "+",
                    .{},
                    text_options.override(.{ .id_extra = getAndIncrementUid() }),
                );
            }
            drawKey(text, color);
        }
    }
}

fn getAndIncrementUid() usize {
    uid += 1;
    return uid;
}
