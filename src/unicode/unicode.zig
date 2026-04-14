pub const PHYSICAL_CHAR_VALUE_ALLOC_SIZE = 8;

pub const CodePoint = u21;
pub const CodePointRange = struct {
    start: CodePoint,
    end: CodePoint,
};
pub const Block = struct {
    range: CodePointRange,
    name: []const u8,
};
