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

const SIZEOF_HEADER_ENTRY = @sizeOf(u32);

pub fn main() !void {
    var names_lines_it = std.mem.tokenizeAny(u8, names_txt, "\n\r");

    var file_name_buf: [256]u8 = undefined;
    var writer_buf: [2048]u8 = undefined;
    var header_writer_buf: [4]u8 = undefined;
    var done_writing_chars = false;
    blocks_loop: for (blocks) |block| {
        std.debug.print("doing block {s}...", .{block.name});
        const file_path = try std.fmt.bufPrint(&file_name_buf, "out/{s}.bin", .{block.name});
        std.mem.replaceScalar(u8, file_path, ' ', '_');
        var out_file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
        defer out_file.close();
        if (done_writing_chars) {
            std.debug.print("\x1b[33mskipped\x1b[0m\n", .{});
            continue :blocks_loop;
        }

        // first loop: see how many names are actually in this block
        var num_header_entries: usize = 0; // number of names in this block, plus non-named code points at beginning (zeroes)
        const names_lines_it_index_at_start_of_block = names_lines_it.index;
        var target_code_point = block.range.start;
        chars_loop: while (names_lines_it.peek()) |names_line| {
            defer target_code_point += 1;
            var line_parts_it = std.mem.tokenizeScalar(u8, names_line, '\t');
            const code_point = try std.fmt.parseInt(u21, line_parts_it.next().?, 16);

            if (code_point < block.range.start) {
                // this should never happen
                std.debug.panic("named code point 0x{x} was less then block '{s}'s starting code point: 0x{x} - panicking\n", .{ code_point, block.name, block.range.start });
            } else if (code_point > block.range.end) {
                if (num_header_entries > 0) {
                    // done, start writing to file
                    break :chars_loop;
                } else {
                    // this block has no names in it
                    std.debug.print("\x1b[33mskipped\x1b[0m\n", .{});
                    continue :blocks_loop;
                }
            }
            num_header_entries += 1;
            if (code_point > target_code_point) {
                // non-named code point, skip but still add size to header
                continue :chars_loop;
            }
            // this matches the functionality of zig's `TokenIterator.next()`
            names_lines_it.index += names_line.len;
        }

        // there are names in this block; create file and get parallel writers ready
        var out_file_writer = out_file.writer(&writer_buf);
        var out_writer = &out_file_writer.interface;
        var header_file_writer = out_file.writer(&header_writer_buf);
        var header_writer = &header_file_writer.interface;

        // second loop; write to file
        names_lines_it.index = names_lines_it_index_at_start_of_block;
        target_code_point = block.range.start;
        try header_writer.writeInt(u16, @intCast(num_header_entries), .little);
        var name_pos: u32 = @intCast((num_header_entries * SIZEOF_HEADER_ENTRY) + @sizeOf(u16));
        try out_file_writer.seekTo(name_pos);
        // write the index of the highest code point value in this file
        chars_loop: while (names_lines_it.peek()) |names_line| {
            defer target_code_point += 1;
            var line_parts_it = std.mem.tokenizeScalar(u8, names_line, '\t');
            const code_point = try std.fmt.parseInt(u21, line_parts_it.next().?, 16);

            if (code_point > block.range.end) {
                try header_writer.flush();
                try out_file_writer.end();
                std.debug.print("\x1b[32mdone\x1b[0m\n", .{});
                continue :blocks_loop;
            }
            if (code_point > target_code_point) {
                try header_writer.writeInt(u32, 0, .little);
                continue :chars_loop;
            }

            const char_name = line_parts_it.next().?;
            try out_writer.writeInt(u8, @intCast(char_name.len), .little);
            _ = try out_writer.write(char_name);
            try header_writer.writeInt(u32, name_pos, .little);
            name_pos += @intCast(char_name.len + 1);

            // this matches the functionality of zig's `TokenIterator.next()`
            names_lines_it.index += names_line.len;
        }
        // no more lines in names.txt, done
        try header_writer.flush();
        try out_file_writer.end();
        std.debug.print("\x1b[32mdone with all\x1b[0m\n", .{});
        done_writing_chars = true;
    }
}

/// Like `(std.Io.Reader).takeInt()` or `std.mem.readInt()`, but no reader needed. Generates less machine code.
/// Unsafe? Very
inline fn getIntFromDataAtOffs(comptime T: type, data: []const u8, offs: usize) T {
    return @as(*T, @ptrCast(@alignCast(@constCast(data[offs..])))).*;
}

// this one doesn't actually assert anything it just prints out stuff
test "various names can be read correctly" {
    var allocator = std.testing.allocator;

    const bin_file = try std.fs.cwd().openFile("out/Basic_Latin.bin", .{ .mode = .read_only });
    defer bin_file.close();

    var reader_buf: [2048]u8 = undefined;
    var bin_file_reader = bin_file.reader(&reader_buf);
    var bin_reader = &bin_file_reader.interface;
    const bytes = try bin_reader.allocRemaining(allocator, .unlimited);
    defer allocator.free(bytes);

    for (0..100) |i| {
        const header_addr = (i * @sizeOf(u32)) + @sizeOf(u16);
        const name_addr = std.mem.readInt(u32, @ptrCast(bytes[header_addr..]), .little);
        std.debug.print("name addr: {x}\n", .{name_addr});
        const name_len: u8 = bytes[name_addr];
        const name = bytes[name_addr + 1 .. name_addr + 1 + name_len];
        std.debug.print("name: {s}\n", .{name});
    }
}
test "first and last Ugaritic name can be retrieved from specific code point" {
    var allocator = std.testing.allocator;

    const bin_file = try std.fs.cwd().openFile("out/Ugaritic.bin", .{ .mode = .read_only });
    defer bin_file.close();

    var reader_buf: [2048]u8 = undefined;
    var bin_file_reader = bin_file.reader(&reader_buf);
    var bin_reader = &bin_file_reader.interface;
    const bytes = try bin_reader.allocRemaining(allocator, .unlimited);
    defer allocator.free(bytes);

    // first
    {
        const code_point: u21 = 0; // 0x10380, 0 in relation to block
        const header_addr = (code_point * @sizeOf(u32)) + @sizeOf(u16);
        const name_addr = std.mem.readInt(u32, @ptrCast(bytes[header_addr..]), .little);
        const name_len = bytes[name_addr];
        const name = bytes[name_addr + 1 .. name_addr + 1 + name_len];
        try std.testing.expectEqualSlices(u8, "UGARITIC LETTER ALPA", name);
    }
    // last
    {
        const code_point: u21 = 0x1039F - 0x10380; // last char in block
        const header_addr = (code_point * @sizeOf(u32)) + @sizeOf(u16);
        const name_addr = std.mem.readInt(u32, @ptrCast(bytes[header_addr..]), .little);
        const name_len = bytes[name_addr];
        const name = bytes[name_addr + 1 .. name_addr + 1 + name_len];
        try std.testing.expectEqualSlices(u8, "UGARITIC WORD DIVIDER", name);
    }
}
