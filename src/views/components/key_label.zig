const dvui = @import("dvui");

pub fn doFrame(text: []const u8) void {
    dvui.labelNoFmt(@src(), text, .{}, .{
        .border = .{
            .x = 1,
            .y = 1,
            .w = 1,
            .h = 3,
        },
        .font = dvui.Font.theme(.body).withSize(8),
    });
}
