const std = @import("std");

const dvui = @import("dvui");
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;

const unicode = @import("unicode/unicode.zig");
const App = @import("App.zig");

// DEBUG
const gnu_unifont = @embedFile("assets/gnu-unifont.otf");
// const segoe_ui_symbol = @embedFile("assets/seguisym.ttf");
// const segoe_ui_historic = @embedFile("assets/seguihis.ttf");

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

var app: App = .{
    .state = .BlockSelect,
};

const fonts_to_load: []const struct { []const u8, []const u8 } = @import("fonts.zon");
var arena: std.heap.ArenaAllocator = undefined;
fn init(_: *dvui.Window) !void {
    arena = .init(std.heap.page_allocator);

    // load fonts
    var file_read_buf: [4096]u8 = undefined;
    inline for (fonts_to_load) |font| {
        if (std.fs.openFileAbsolute("C:\\Windows\\Fonts\\" ++ font.@"0", .{ .mode = .read_only })) |font_file| {
            var font_file_reader = font_file.reader(&file_read_buf);
            var font_reader = &font_file_reader.interface;
            const font_ttf_bytes = try font_reader.allocRemaining(arena.allocator(), .unlimited);
            try dvui.addFont(font.@"1", font_ttf_bytes, null);
        } else |_| {} // font file not found on the user's computer
    }

    // possibly add gnu unifont here
}
fn deinit() void {
    arena.deinit();
}
fn frame() !dvui.App.Result {
    {
        var scaler = dvui.scale(
            @src(),
            .{
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
