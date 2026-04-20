const std = @import("std");
const log = std.log;

const dvui = @import("dvui");
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
const dx11 = @import("dvui-backend");

const c = @cImport({
    @cInclude("windows.h");
});

const unicode = @import("unicode/unicode.zig");
const App = @import("App.zig");
const favicon = @embedFile("unimap-64.png");

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 800, .h = 600 },
            .title = "Unimap",
            .icon = favicon,
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
fn init(win: *dvui.Window) !void {
    // make window not resizable
    // const hwnd = dx11.hwndFromContext(win.backend.impl);
    // const style = dx11.win32.GetWindowLongPtrA(@ptrCast(hwnd), dx11.win32.GWL_STYLE);
    // const res = dx11.win32.SetWindowLongPtrA(@ptrCast(hwnd), dx11.win32.GWL_STYLE, style & ~(c.WS_SIZEBOX | c.WS_MAXIMIZEBOX)); // TODO: see if you can remove the title bar here
    // if (res == 0) {
    //     log.err("could not set window style", .{});
    // }

    // TODO: set window icon (DVUI's DX11 backend seems to be broken in this regard)

    arena = .init(std.heap.page_allocator);

    // load fonts
    const thread = try std.Thread.spawn(.{}, loadFonts, .{win});
    thread.detach();
}
fn deinit() void {
    arena.deinit();
}
fn frame() !dvui.App.Result {
    app.frame();

    if (is_loading_fonts) {
        dvui.toast(@src(), .{ .message = "loading fonts...", .timeout = 1 });
    }

    return .ok;
}

pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};

const WINDOWS_FONTS_PATH = "C:\\Windows\\Fonts\\";
var is_loading_fonts = false;
fn loadFonts(win: *dvui.Window) !void {
    is_loading_fonts = true;
    var file_read_buf: [4096]u8 = undefined;
    inline for (fonts_to_load) |font| {
        if (std.fs.openFileAbsolute(WINDOWS_FONTS_PATH ++ font.@"0", .{ .mode = .read_only })) |font_file| {
            var font_file_reader = font_file.reader(&file_read_buf);
            var font_reader = &font_file_reader.interface;
            const font_ttf_bytes = try font_reader.allocRemaining(arena.allocator(), .unlimited);
            try win.addFont(font.@"1", font_ttf_bytes, null);
        } else |_| {
            log.warn("could not find font at path '" ++ WINDOWS_FONTS_PATH ++ "{s}' on your computer", .{font.@"0"});
        } // font file not found on the user's computer
    }
    is_loading_fonts = false;
}
