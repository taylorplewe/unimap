//! This is a small program to generate the compact binary files containing the names of every single Unicode character,
//! for use in the Unimap program.
//!
//! Unicode, Inc. hosts a gigantic ~2MB file called `NamesList.txt` at https://www.unicode.org/Public/UCD/latest/ucd/ as part of the "Unicode Character Database".
//! This file, even when stripped down to contain only the unique names, still has over 40,000 character names listed.
//!
//! In order to achieve quick O(1) lookup of names, I've decided to create compact, headered binary files containing every character's name, per block.
//! This is because there's big holes in between some blocks where code points don't have any names attached to them, so I couldn't just have one big file.
//!
//! a symlink to the `unicode` directory from the main program exists in this `src` directory

const std = @import("std");
const unicode = @import("unicode/unicode.zig");
const names_txt: []const u8 = @embedFile("unicode/names.txt");
pub const blocks: []const unicode.Block = @import("unicode/blocks.zon");

pub fn main() !void {
    var names_lines_it = std.mem.tokenizeScalar(u8, names_txt, '\n');

    var i: usize = 0;
    var file_name_buf: [256]u8 = undefined;
    var writer_buf: [2048]u8 = undefined;
    var header_writer_buf: [4]u8 = undefined;
    blocks_loop: for (blocks) |block| {
        var target_code_point = block.range.start;
        const file_path = try std.fmt.bufPrint(&file_name_buf, "out/{s}.bin", .{block.name});
        std.mem.replaceScalar(u8, file_path, ' ', '_');
        var out_file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });

        var out_file_writer = out_file.writer(&writer_buf);
        var out_writer = &out_file_writer.interface;

        var header_file_writer = out_file.writer(&header_writer_buf);
        var header_writer = &header_file_writer.interface;

        const header_size: usize = (block.range.end - block.range.start) * @sizeOf(u32);
        try out_file_writer.seekTo(header_size);
        var name_pos: u32 = @intCast(header_size);

        std.debug.print("block {s}\n", .{block.name});
        i += 1;
        if (i > 3) break :blocks_loop;
        chars_loop: while (names_lines_it.peek()) |names_line| {
            var line_parts_it = std.mem.tokenizeScalar(u8, names_line, '\t');

            const code_point = try std.fmt.parseInt(u21, line_parts_it.next().?, 16);

            if (code_point > block.range.end or code_point < block.range.start) {
                try header_writer.flush();
                try out_file_writer.end();
                out_file.close();
                continue :blocks_loop;
            }
            if (code_point < target_code_point) {
                try header_writer.writeInt(u32, 0, .little);
                continue :chars_loop;
            }

            const char_name = line_parts_it.next().?;
            try out_writer.writeInt(u8, @intCast(char_name.len), .little);
            _ = try out_writer.write(char_name);
            try header_writer.writeInt(u32, name_pos, .little);
            name_pos += @intCast(char_name.len + 1);

            target_code_point += 1;
            names_lines_it.index += names_line.len;
            // pub fn next(self: *Self) ?[]const T {
            //     const result = self.peek() orelse return null;
            //     self.index += result.len;
            //     return result;
            // }
        }
        break :blocks_loop;
    }
}
