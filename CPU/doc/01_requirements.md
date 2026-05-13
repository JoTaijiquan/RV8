# RV8 — Requirements

## Goals

| # | Goal |
|---|------|
| G1 | Minimum chip count (26 total) for educational build |
| G2 | Fixed 2-byte instruction format (uniform fetch) |
| G3 | 16-bit address bus (64KB) |
| G4 | 8-bit data bus |
| G5 | Accumulator architecture (all ALU → a0) |
| G6 | Buildable on breadboard with 74HC chips |
| G7 | Single-step debugging (via Trainer board clock override) |
| G8 | Capable of running BASIC interpreter |

## Constraints

| Constraint | Value | Reason |
|-----------|-------|--------|
| Max chips | 26 | Fits 4 breadboards |
| Supply | 5V USB | 74HC + AT28C256 + 62256 all 5V |
| Clock | 3.5 MHz | Safe for breadboard wiring |
| ROM | 32KB (AT28C256) | Program storage, $C000-$FFFF |
| RAM | 32KB (62256) | Data, $0000-$7FFF |
| I/O | Memory-mapped | $8000-$9FFF |

## Memory Map

```
$0000-$7FFF  RAM (32KB)
$8000-$9FFF  I/O (8KB window)
$C000-$FFFF  ROM (16KB visible, banked from 32KB)
$FFF6-$FFF7  TRAP vector
$FFFA-$FFFB  NMI vector
$FFFC-$FFFD  RESET vector
$FFFE-$FFFF  IRQ vector
```

## Registers

| Name | Width | Purpose |
|------|:-----:|---------|
| c0 | 8 | Constant generator (0, 1, $FF, $80) |
| sp | 8 | Stack pointer (stack at page $30) |
| a0 | 8 | Accumulator (ALU destination) |
| pl | 8 | Pointer low byte |
| ph | 8 | Pointer high byte |
| t0 | 8 | Temporary register |
| pg | 8 | Page register (high byte for page-relative) |

## Instruction Groups

| Group | Count | Examples |
|-------|:-----:|---------|
| ALU register | 8 | ADD, SUB, AND, OR, XOR, CMP, ADC, SBC |
| ALU immediate | 7 | ADDI, SUBI, CMPI, ANDI, ORI, XORI, TST |
| Load immediate | 6 | LI sp/a0/pl/ph/t0/pg |
| Load/Store | 14 | LB/SB ptr, ptr+, sp+imm, zp, pg:imm, MOV, PUSH, POP |
| Branch | 7 | BEQ, BNE, BCS, BCC, BMI, BPL, BRA |
| Skip | 4 | SKIPZ, SKIPNZ, SKIPC, SKIPNC |
| Jump | 3 | JMP, JAL, RET |
| Shift/Unary | 8 | SHL, SHR, ROL, ROR, INC, DEC, NOT, SWAP |
| Pointer | 3 | INC16, DEC16, ADD16 |
| System | 8 | CLC, SEC, EI, DI, RTI, TRAP, NOP, HLT |
| **Total** | **68** | |

## Interrupts

| Source | Vector | Edge/Level | Maskable |
|--------|--------|-----------|----------|
| RESET | $FFFC | — | No |
| NMI | $FFFA | Falling edge | No |
| IRQ | $FFFE | Low level | Yes (IE flag) |
| TRAP | $FFF6 | Instruction | — |

## System Architecture

```
┌──────────────────────────────────────────────┐
│  CPU Board (26 chips, self-contained)        │
│  Crystal on-board, always free-running       │
└───────────────┬──────────────────────────────┘
                │ RV8-Bus (40-pin)
    ┌───────────┼───────────┐
    ▼           ▼           ▼
Programmer  Trainer/     Computer/
(ROM flash  (~10 chips)  (full PC)
 + UART)
```

The CPU board runs standalone with its own clock.
Host boards (Programmer, Trainer, Computer) plug into the RV8-Bus:
- Programmer: ROM flash + UART terminal (minimum viable host)
- Trainer: clock override, step, LEDs, 7-seg, SD, keyboard, PS/2
- Computer: expanded I/O, storage, OS-capable

## CPU Board Status

| Component | Status |
|-----------|:------:|
| ISA design (68 instructions) | ✅ |
| Verilog (69 tests pass) | ✅ |
| Circuit design (26 chips) | ✅ |
| KiCad schematic (387 wires) | ✅ |
| Lab sheets (12 labs, Thai+English) | ✅ |
| Build guide + pin wiring tables | ✅ |
| Cross-assembler | ✅ |
| Breadboard build | ⬜ |
| PCB layout | ⬜ |
