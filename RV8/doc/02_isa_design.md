# RV8 — ISA Design Decisions

Key design choices and why.

## Fixed 2-Byte Instructions

Every instruction is exactly 2 bytes: `[opcode] [operand]`.
- PC always increments by 2 — no length decoder needed
- Fetch is trivial: clock 1 = opcode, clock 2 = operand
- Students can hand-assemble in hex

## Accumulator Model

All ALU results go to a0 (accumulator). No destination register field.
- Saves 2-3 opcode bits (no dst encoding)
- Simpler datapath (one write-back path)
- Matches 6502 model (proven for 8-bit)

## Direct-Encoded Opcodes

```
opcode[7:5] = unit select (ALU, IMM, LDST, BRANCH, SHIFT, PTR, -, SYS)
opcode[4:2] = operation within unit
opcode[1:0] = register select or modifier
```

No microcode ROM. The opcode bits directly drive the control signals via a 74HC138 decoder + gates. This saves 1 chip and removes the speed limit of a microcode ROM.

## 7 Registers (Not 4, Not 16)

| Reg | Why |
|-----|-----|
| c0 | Constant generator — eliminates LI for common values (0, 1, -1, $80) |
| sp | 8-bit stack pointer — stack at fixed page $30 |
| a0 | Accumulator — all ALU results land here |
| pl, ph | 16-bit pointer — essential for memory access beyond zero-page |
| t0 | Temporary — needed for swap, multi-step operations |
| pg | Page register — enables page-relative addressing |

## Conditional Skip (Not Predication)

Instead of conditional execution on every instruction:
```
SKIPZ       ; skip next instruction if Z=1
ADD t0      ; this gets skipped if Z was set
```
- Costs 0 extra hardware (just a 1-bit flag that suppresses one write)
- More flexible than branch for single-instruction conditionals
- Saves code space vs branch-over pattern

## Auto-Increment Pointer (ptr+)

`LB (ptr+)` and `SB (ptr+)` automatically increment {ph,pl} after access.
- Critical for string/array scanning
- 40% fewer instructions in inner loops
- Cost: just the carry chain on the 74HC161 counters (already there)

## 8-Bit Stack Pointer on Fixed Page

Stack address = {$30, SP}. SP is only 8 bits.
- No 16-bit SP register needed (saves 1 chip)
- 256 bytes = 128 nested calls (more than enough)
- Page $30 chosen to avoid conflict with zero-page ($00) and I/O ($80)

## Hardwired Control (Not Microcode)

| | Microcode | Hardwired |
|--|-----------|-----------|
| Speed | Limited by ROM access time | Full clock speed |
| Chips | 1 ROM + decode | ~6 logic chips |
| Flexibility | Easy to change | Fixed |
| Cost | $10 (EEPROM) | $3 (logic) |

Hardwired chosen: same chip count, faster, cheaper. The direct-encoded opcode format makes hardwired control simple.

## Branch: Byte-Relative Offset

`BNE offset` — PC = PC + 2 + sign_extend(offset)
- Range: -128 to +127 bytes (±63 instructions)
- Sufficient for all loops
- For longer jumps: `JMP (ptr)` using {ph,pl}

## Interrupts: NMI + IRQ

- NMI: edge-triggered, non-maskable (for critical events)
- IRQ: level-triggered, maskable via IE flag
- Both push PC + flags, jump to vector
- RTI restores everything

## What Was Rejected

| Feature | Why rejected |
|---------|-------------|
| PC-relative data | +2 chips, rarely needed, ptr works fine |
| Hardware multiply | +150 gates, software is fast enough |
| 16-bit SP | +1 chip, 256-byte stack is sufficient |
| DMA | +7 chips, not needed for education |
| Floating point | +2500 gates, software FP in ROM |
| Variable-length instructions | Complex fetch, not worth it |
