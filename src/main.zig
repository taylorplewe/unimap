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
            .title = "Taylor's Sick DVUI App",
        },
    },
    .initFn = init,
    .deinitFn = deinit,
    .frameFn = frame,
};

fn comptimeParseUpperHex(comptime T: type, comptime str: []const u8) T {
    var res: T = 0;
    var i: isize = str.len - 1;
    while (i >= 0) : (i -= 1) {
        const pow = (str.len - i) * 10;
        res += if (std.ascii.isDigit(str[i]))
            ((str[i]) - '0') * pow
        else
            (((str[i]) - 'A') + 10) * pow;
    }
    return res;
}

fn init(_: *dvui.Window) !void {
    std.debug.print("num blocks: {d}\n", .{blocks.len});
    std.debug.print("first range:\n start: {d}\n end: {d}\n", .{ blocks[0].range.start, blocks[0].range.end });
}
fn deinit() void {}
fn frame() !dvui.App.Result {
    return .ok;
}

pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};
