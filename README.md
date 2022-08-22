# Birtual Machine

This is a virtual machine meant to be targeted by programming languages, but kind of works as a language in itself (see [examples](examples) for examples of code written in BASM).
It is stack-based and supports named labels, and both integer and floating-point instructions. Not all instructions work yet besides the ones used in examples.

## Compilation

The project builds with [Zig](https://ziglang.org) and [Gyro](https://github.com/mattnite/gyro).

To build:
```console
gyro build
```

Three executables will be created in zig-out/bin. They are described below.

### basm
The assembler takes an input file (conventionally, \*.basm) and converts it to machine-specific bytecode (conventionally, \*.bm).
Labels are supported here, and jumps may refer to absolute offsets or label names.

```console
./zig-out/bin/basm examples/e.basm examples/e.bm
# OR, using `zig build`:
zig build run-basm -- examples/e.basm examples/e.bm
```

### bme
The emulator takes an input file (\*.bm) and simulates the machine. The value at the top of the stack can be dumped with the `print_debug` instruction,
or the entire stack may be dumped by passing `-d` to bme. (The latter will also allow stepping instruction by instruction.)

```console
./zig-out/bin/bme -i examples/e.bm
# OR, using `zig build`:
zig build run-bme -- -i examples/e.bm
```

### debasm
The disassembler takes the bytecode file and converts it back to BASM assembly. It is guaranteed that
the output of `debasm` may be passed back to `basm` and create identical bytecode.

Note that floating-point values are represented as unsigned 64-bit ints internally, so those may appear garbled. They are still
interpreted correctly due to the separation of integer and floating-point operations.

```console
./zig-out/bin/debasm examples/e.bm
# OR, using `zig build`:
zig build run-debasm -- examples/e.bm
```
