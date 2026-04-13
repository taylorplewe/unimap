const std = @import("std");

const dvui = @import("dvui");
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;

const unicode = @import("unicode/unicode.zig");
const App = @import("App.zig");

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 800, .h = 600 },
            .min_size = .{ .w = 600, .h = 300 },
            .title = "Unimap",
        },
    },
    .initFn = init,
    .deinitFn = deinit,
    .frameFn = frame,
};

var app: App = .{
    .state = .BlockSelect,
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

        app.frame();
    }
    return .ok;
}

pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};
