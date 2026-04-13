const std = @import("std");

const dvui = @import("dvui");
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;

const unicode = @import("unicode/unicode.zig");
const blocks: []const unicode.Block = @import("unicode/blocks.zon");

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 800, .h = 600 },
            .title = "Unimap",
        },
    },
    .initFn = init,
    .deinitFn = deinit,
    .frameFn = frame,
};

fn init(_: *dvui.Window) !void {}
fn deinit() void {}
fn frame() !dvui.App.Result {
    {
        var scaler = dvui.scale(
            @src(),
            .{
                .scale = &dvui.currentWindow().content_scale,
                .pinch_zoom = .global,
            },
            .{ .rect = .cast(dvui.windowRect()) },
        );
        defer scaler.deinit();

        var scroll = dvui.scrollArea(
            @src(),
            .{},
            .{ .expand = .both, .style = .window },
        );
        defer scroll.deinit();

        for (blocks) |block| {
            if (dvui.button(@src(), block.name, .{}, .{ .id_extra = block.range.start })) {
                std.debug.print("clicked: {s}\n", .{block.name});
            }
        }
    }
    return .ok;
}

pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};
