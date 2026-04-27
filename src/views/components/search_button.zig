const dvui = @import("dvui");

const search = @import("../../search.zig");
const key_label = @import("key_label.zig");

pub fn doFrame() void {
    const text_color = dvui.themeGet().text.opacity(0.5);
    const text_color_hover = dvui.themeGet().text;

    var btn: dvui.ButtonWidget = undefined;
    defer btn.deinit();
    btn.init(
        @src(),
        .{},
        .{
            .padding = .all(0),
            .color_fill = .transparent,
        },
    );
    btn.processEvents();
    btn.drawBackground();
    const clicked = btn.clicked();

    var hbox = dvui.box(@src(), .{ .dir = .horizontal }, .{});
    defer hbox.deinit();

    dvui.icon(
        @src(),
        "search",
        dvui.entypo.magnifying_glass,
        .{},
        .{
            .gravity_y = 0.5,
            .margin = .{ .x = 0, .y = 0, .w = 4, .h = 0 },
            .color_text = if (btn.hover) text_color_hover else text_color,
        },
    );
    dvui.labelNoFmt(
        @src(),
        "Search",
        .{},
        .{
            .margin = .{ .x = 0, .y = 0, .w = 4, .h = 0 },
            .color_text = if (btn.hover) text_color_hover else text_color,
        },
    );
    key_label.doFrame("/", if (btn.hover) text_color_hover else text_color);

    if (!search.show_search_window) {
        for (dvui.events()) |e| {
            switch (e.evt) {
                .key => {
                    if ((e.evt.key.mod == .none and e.evt.key.code == .slash) or (e.evt.key.mod.control() and e.evt.key.code == .k)) {
                        search.show_search_window = true;
                    }
                },
                else => break,
            }
        }
    }
    if (clicked) search.show_search_window = true;
}
