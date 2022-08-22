const defs = @import("defs.zig");

const Word = defs.Word;

pub const Instruction = union(enum) {
    Nop,
    Push: Word,
    Dup: Word,
    Swap: Word,
    Drop,
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
    Ret,
    Call: Word,
    Native: Word,
    Eq,
    GeF,
    LtF,
    Not,
    Halt,
    PrintDebug,

    const Tag = @typeInfo(Instruction).Union.tag_type.?;

    pub fn name(t: Tag) []const u8 {
        return switch (t) {
            .Nop => "nop",
            .Push => "push",
            .Dup => "dup",
            .Swap => "swap",
            .Drop => "drop",
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
            .Ret => "ret",
            .Call => "call",
            .Native => "native",
            .Eq => "eq",
            .GeF => "gef",
            .LtF => "ltf",
            .Not => "not",
            .Halt => "halt",
            .PrintDebug => "print_debug",
        };
    }

    pub fn operand(i: *Instruction) ?*Word {
        return switch (i.*) {
            .Push,
            .Dup,
            .Swap,
            .Jump,
            .JumpIf,
            .Call,
            .Native,
            => |*operand| operand,
            else => null,
        };
    }
};
