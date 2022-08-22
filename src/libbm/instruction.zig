const defs = @import("defs.zig");

const Word = defs.Word;

pub const Instruction = union(enum) {
    Nop,
    Push: Word,
    Dup: Word,
    Swap: Word,
    PlusI,
    MinusI,
    MultI,
    DivI,
    PlusF,
    MinusF,
    MultF,
    DivF,
    Jump: Word,
    JumpIf: Word,
    Eq,
    Halt,
    PrintDebug,

    const Tag = @typeInfo(Instruction).Union.tag_type.?;

    pub fn name(t: Tag) []const u8 {
        return switch (t) {
            .Nop => "nop",
            .Push => "push",
            .Dup => "dup",
            .Swap => "swap",
            .PlusI => "plusi",
            .MinusI => "minusi",
            .MultI => "multi",
            .DivI => "divi",
            .PlusF => "plusf",
            .MinusF => "minusf",
            .MultF => "multf",
            .DivF => "divf",
            .Jump => "jmp",
            .JumpIf => "jmp_if",
            .Eq => "eq",
            .Halt => "halt",
            .PrintDebug => "print_debug",
        };
    }

    pub fn operand(i: Instruction) ?Word {
        return switch (i) {
            .Push, .Dup, .Swap, .Jump, .JumpIf => |operand| operand,
            else => null,
        };
    }
};
