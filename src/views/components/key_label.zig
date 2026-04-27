const dvui = @import("dvui");

pub fn doFrame(text: []const u8, color: dvui.Color) void {
    dvui.labelNoFmt(@src(), text, .{}, .{
        .background = true,
        .corner_radius = .all(4),
        .border = .{
            .x = 1,
            .y = 1,
            .w = 1,
            .h = 2,
        },
        .font = dvui.Font.theme(.body).withSize(8),
        .color_border = color,
        .color_text = color,
    });
}
