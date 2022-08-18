const defs = @import("defs.zig");

const Word = defs.Word;

pub const Instruction = union(enum) {
    Push: Word,
    Dup: Word,
    Plus,
    Minus,
    Mult,
    Div,
    Jump: Word,
    JumpIf: Word,
    Eq,
    Halt,
    PrintDebug,
};
