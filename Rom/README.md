# RV8 System ROM

BASIC interpreter + monitor + assembler + bootloader. Fits in 32KB AT28C256.

## Status: Not started

## Memory Layout

```
$C000-$EFFF  BASIC interpreter (12KB)
$F000-$F7FF  Monitor/debugger (2KB)
$F800-$FBFF  Mini assembler (1KB)
$FC00-$FDFF  Character font (512B, for PC board text mode)
$FE00-$FFF5  Bootloader (502B)
$FFF6-$FFFF  Vectors (TRAP, NMI, RESET, IRQ)
```

## Components

### BASIC Interpreter (~12KB)
- Tiny BASIC style (line-numbered)
- Integer arithmetic + software floating point
- String handling (fixed-length or pointer-based)
- Commands: PRINT, INPUT, IF/THEN, GOTO, GOSUB, FOR/NEXT, LET
- Hardware: PEEK, POKE, OUT, INP
- Sound: SOUND freq, duration
- Graphics: PLOT x,y / DRAW x,y / CLS (PC board only)
- Storage: CSAVE/CLOAD (cassette), SAVE/LOAD (SD)
- Memory: ~24KB free for BASIC programs ($0100-$5FFF)

### Monitor/Debugger (~2KB)
- Hex dump memory
- Edit memory bytes
- Disassemble instructions
- Set breakpoint (TRAP)
- Single-step (uses STEP switch)
- Register display
- Go (run from address)

### Mini Assembler (~1KB)
- Single-line assembly (no labels, no macros)
- Immediate assembly to RAM
- Format: `>A C000` then type mnemonics line by line
- Useful for quick patches and learning

### Bootloader (~512B)
- Waits for serial data on reset (1 second timeout)
- If data arrives: receive binary, write to RAM, jump to it
- If timeout: jump to BASIC (normal boot)
- Protocol: length(2B) + data + checksum(1B)

## Files

```
Rom/
├── README.md          ← this file
├── doc/
│   └── requirements.md
├── (basic.asm TBD)
├── (monitor.asm TBD)
├── (assembler.asm TBD)
└── (bootloader.asm — exists in programmer/)
```
