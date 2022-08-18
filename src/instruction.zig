const defs = @import("defs.zig");

const Word = defs.Word;

pub const Instruction = union(enum) {
    Push: Word,
    Plus,
    Minus,
    Mult,
    Div,
};
