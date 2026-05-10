> **⚠️ HISTORICAL DOCUMENT** — This captures the design discussion. For the verified final spec, see `doc/05_isa_reference.md` and `doc/04_architecture.md`.

# RV8 — Instruction Set Architecture Design

**Project**: RV8 Minimal Educational CPU  
**Version**: 3.0  
**Date**: 2026-05-10  
**Phase**: ISA Design

---

## 1. Instruction Format

All instructions are **fixed 2 bytes**:

```
Byte 0: [opcode]    — 8 bits (what to do)
Byte 1: [operand]   — 8 bits (register, immediate, or offset)
```

PC always increments by 2. Fetch is always: read byte 0, read byte 1, execute.

---

## 2. Operand Byte Encoding

Byte 1 interpretation depends on instruction type:

| Type | Byte 1 format | Example |
|------|---------------|---------|
| Register | `000000rr` (bits 1:0 = register) | ADD x3 → [0x00][0x03] |
| Immediate | Full 8-bit value | LI a0, 42 → [0x12][0x2A] |
| Branch offset | Signed 8-bit (byte-relative from PC) | BNE -4 → [0x31][0xFC] |
| Unused | 0x00 (ignored) | RET → [0x3A][0x00] |

---

## 3. Registers

| Encoding | Register | Name | Purpose |
|----------|----------|------|---------|
| 000 | x0 | c0 | Constant generator: {0, 1, -1, 0x80} selected by instruction bits |
| 001 | x1 | sp | Stack pointer (8-bit, page 0x30) |
| 010 | x2 | a0 | Accumulator (implicit ALU dest) |
| 011 | x3 | pl | Pointer low byte |
| 100 | x4 | ph | Pointer high byte |
| 101 | x5 | t0 | Temporary register |
| 110 | x6 | pg | Page register (addr high byte for page-relative) |

Constant generator (x0) output depends on bits [3:2] of operand byte:
- 00 → 0x00, 01 → 0x01, 10 → 0xFF (-1), 11 → 0x80 (sign bit)

When used as `ADD c1`, it adds 1 to a0 (same as INC but through ALU).
When used as `ADD cn`, it adds -1 (same as DEC). Eliminates need for dedicated INC/DEC in some cases.

---

## 4. Instruction Set

### 4.1 ALU — Accumulator Operations

All ALU ops: `a0 = a0 OP source`. Flags updated.

| Opcode | Hex | Mnemonic | Operation | Flags |
|--------|-----|----------|-----------|-------|
| 0x00 | 00 | ADD rs | a0 = a0 + rs | Z, C, N |
| 0x01 | 01 | SUB rs | a0 = a0 - rs | Z, C, N |
| 0x02 | 02 | AND rs | a0 = a0 & rs | Z, N |
| 0x03 | 03 | OR rs | a0 = a0 \| rs | Z, N |
| 0x04 | 04 | XOR rs | a0 = a0 ^ rs | Z, N |
| 0x05 | 05 | CMP rs | flags = a0 - rs (no store) | Z, C, N |
| 0x06 | 06 | ADC rs | a0 = a0 + rs + C | Z, C, N |
| 0x07 | 07 | SBC rs | a0 = a0 - rs - !C | Z, C, N |

Byte 1 = register encoding (bits 1:0).

### 4.2 Immediate Operations

| Opcode | Hex | Mnemonic | Operation | Flags |
|--------|-----|----------|-----------|-------|
| 0x10 | 10 | LI sp, imm | sp = imm8 | — |
| 0x11 | 11 | LI a0, imm | a0 = imm8 | — |
| 0x12 | 12 | LI pl, imm | pl = imm8 | — |
| 0x13 | 13 | LI ph, imm | ph = imm8 | — |
| 0x14 | 14 | LI t0, imm | t0 = imm8 | — |
| 0x15 | 15 | LI pg, imm | pg = imm8 | — |
| 0x16 | 16 | ADDI a0, imm | a0 = a0 + imm8 | Z, C, N |
| 0x17 | 17 | SUBI a0, imm | a0 = a0 - imm8 | Z, C, N |
| 0x18 | 18 | CMPI a0, imm | flags = a0 - imm8 | Z, C, N |
| 0x19 | 19 | ANDI a0, imm | a0 = a0 & imm8 | Z, N |
| 0x1A | 1A | ORI a0, imm | a0 = a0 \| imm8 | Z, N |
| 0x1B | 1B | XORI a0, imm | a0 = a0 ^ imm8 | Z, N |
| 0x1C | 1C | TST imm | flags = a0 & imm8 (no store) | Z, N |

Byte 1 = 8-bit immediate value.

### 4.3 Load/Store

| Opcode | Hex | Mnemonic | Operation | Flags |
|--------|-----|----------|-----------|-------|
| 0x20 | 20 | LB rd, (ptr) | rd = mem[{ph,pl}] | — |
| 0x21 | 21 | SB rs, (ptr) | mem[{ph,pl}] = rs | — |
| 0x22 | 22 | LB rd, (ptr+) | rd = mem[{ph,pl}]; ptr++ | — |
| 0x23 | 23 | SB rs, (ptr+) | mem[{ph,pl}] = rs; ptr++ | — |
| 0x24 | 24 | MOV rd, a0 | rd = a0 | — |
| 0x25 | 25 | MOV a0, rs | a0 = rs | — |
| 0x26 | 26 | LB a0, [sp+imm] | a0 = mem[{0x30, sp+imm8}] | — |
| 0x27 | 27 | SB a0, [sp+imm] | mem[{0x30, sp+imm8}] = a0 | — |
| 0x28 | 28 | LB a0, [zp+imm] | a0 = mem[{0x00, imm8}] | — |
| 0x29 | 29 | SB a0, [zp+imm] | mem[{0x00, imm8}] = a0 | — |
| 0x2A | 2A | LB a0, [pg:imm] | a0 = mem[{pg, imm8}] | — |
| 0x2B | 2B | SB a0, [pg:imm] | mem[{pg, imm8}] = a0 | — |

Byte 1 = register encoding (bits 1:0) for 0x20-0x25.  
Byte 1 = unsigned 8-bit offset for 0x26-0x2B.

**Stack-relative** (0x26-0x27): Address = {0x30, SP + offset}. Fast local variable access.  
**Zero-page** (0x28-0x29): Address = {0x00, offset}. Fast global variable access (256 bytes).  
**Page-relative** (0x2A-0x2B): Address = {pg, offset}. Access any 256-byte page set by `LI pg, imm`. Equivalent to 6502 absolute addressing in 2 bytes.

### 4.4 Stack

| Opcode | Hex | Mnemonic | Operation | Flags |
|--------|-----|----------|-----------|-------|
| 0x2C | 2C | PUSH rs | sp--; mem[{0x30,sp}] = rs | — |
| 0x2D | 2D | POP rd | rd = mem[{0x30,sp}]; sp++ | — |

Byte 1 = register encoding (bits 1:0).

### 4.5 Branch (PC-relative, byte offset)

| Opcode | Hex | Mnemonic | Condition |
|--------|-----|----------|-----------|
| 0x30 | 30 | BEQ offset | Z == 1 |
| 0x31 | 31 | BNE offset | Z == 0 |
| 0x32 | 32 | BCS offset | C == 1 |
| 0x33 | 33 | BCC offset | C == 0 |
| 0x34 | 34 | BMI offset | N == 1 (negative) |
| 0x35 | 35 | BPL offset | N == 0 (positive) |
| 0x36 | 36 | BRA offset | Always (unconditional) |
| 0x37 | 37 | SKIPZ | If Z==1: next instruction executes as NOP |
| 0x38 | 38 | SKIPNZ | If Z==0: next instruction executes as NOP |
| 0x39 | 39 | SKIPC | If C==1: next instruction executes as NOP |
| 0x3A | 3A | SKIPNC | If C==0: next instruction executes as NOP |

Byte 1 = signed 8-bit offset for branches (0x30-0x36).  
Byte 1 = 0x00 (unused) for skip instructions (0x37-0x3A).

Branch target = PC + sign_extend(offset). PC already advanced after fetch.  
Skip: no branch penalty — next instruction is fetched but write-enables are suppressed.

### 4.6 Jump

| Opcode | Hex | Mnemonic | Operation |
|--------|-----|----------|-----------|
| 0x3C | 3C | JMP (ptr) | PC = {ph, pl} |
| 0x3D | 3D | JAL (ptr) | push PCH; push PCL; PC = {ph,pl} |
| 0x3E | 3E | RET | pop PCL; pop PCH |

Byte 1 = 0x00 (unused).

### 4.7 Shift/Unary

| Opcode | Hex | Mnemonic | Operation | Flags |
|--------|-----|----------|-----------|-------|
| 0x40 | 40 | SHL rd | rd <<= 1, C = old bit7 | Z, C, N |
| 0x41 | 41 | SHR rd | rd >>= 1, C = old bit0 | Z, C, N |
| 0x42 | 42 | ROL rd | rd = {rd[6:0], C}, C = old bit7 | Z, C, N |
| 0x43 | 43 | ROR rd | rd = {C, rd[7:1]}, C = old bit0 | Z, C, N |
| 0x44 | 44 | INC rd | rd = rd + 1 | Z, N |
| 0x45 | 45 | DEC rd | rd = rd - 1 | Z, N |
| 0x46 | 46 | NOT rd | rd = ~rd | Z, N |
| 0x47 | 47 | SWAP rd | rd = {rd[3:0], rd[7:4]} (swap nibbles) | Z, N |

Byte 1 = register encoding (bits 1:0).

### 4.8 Pointer Arithmetic

| Opcode | Hex | Mnemonic | Operation | Flags |
|--------|-----|----------|-----------|-------|
| 0x48 | 48 | INC16 ptr | {ph,pl} = {ph,pl} + 1 | — |
| 0x49 | 49 | DEC16 ptr | {ph,pl} = {ph,pl} - 1 | — |
| 0x4A | 4A | ADD16 ptr, imm | {ph,pl} = {ph,pl} + imm8 (unsigned) | C |

Byte 1: 0x00 for INC16/DEC16, immediate for ADD16.

### 4.9 System/Misc

| Opcode | Hex | Mnemonic | Operation |
|--------|-----|----------|-----------|
| 0xF0 | F0 | CLC | C = 0 |
| 0xF1 | F1 | SEC | C = 1 |
| 0xF2 | F2 | EI | Enable interrupts (IE = 1) |
| 0xF3 | F3 | DI | Disable interrupts (IE = 0) |
| 0xF4 | F4 | RTI | Pop Flags, pop PCL, pop PCH (return from interrupt) |
| 0xF5 | F5 | TRAP imm | System call: push PC, jump to vector 0xFFF6. Byte 1 = trap number (in a0 on entry) |
| 0xFE | FE | NOP | No operation (alias: ADD x0, no side effects) |
| 0xFF | FF | HLT | Halt clock (wakes on NMI or IRQ if IE=1, else permanent) |

Byte 1 = 0x00 (unused) except TRAP (byte 1 = trap number passed to handler).

**HLT behavior**:
- If IE=0: permanent halt (needs RESET)
- If IE=1: sleeps until interrupt, then resumes (replaces WFI)

**TRAP** replaces both ECALL and EBREAK:
- TRAP 0 = system call (ECALL equivalent)
- TRAP 1 = breakpoint (EBREAK equivalent)
- TRAP 2-255 = user-defined traps

---

## 5. Flags Register

| Bit | Name | Set by |
|-----|------|--------|
| 0 | Z (Zero) | ALU ops, CMP, INC, DEC, shift, logic, TST |
| 1 | C (Carry) | ADD, SUB, ADC, SBC, CMP, SHL, SHR, ROL, ROR |
| 2 | N (Negative) | Result bit 7 (sign bit) |
| 3 | IE (Interrupt Enable) | EI, DI, RTI |

Note: N flag is set automatically by ALU results. No manual clear needed (any ALU op resets it).  
IE is stored separately. On interrupt entry, IE is cleared. RTI restores previous IE state from stack.

---

## 6. Instruction Summary

| Count | Category |
|-------|----------|
| 8 | ALU register (ADD, SUB, AND, OR, XOR, CMP, ADC, SBC) |
| 13 | Immediate (LI×6, ADDI, SUBI, CMPI, ANDI, ORI, XORI, TST) |
| 12 | Load/Store (LB/SB ptr, LB/SB ptr+, MOV×2, LB/SB sp+imm, LB/SB zp+imm, LB/SB pg:imm) |
| 2 | Stack (PUSH, POP) |
| 7 | Branch (BEQ, BNE, BCS, BCC, BMI, BPL, BRA) |
| 4 | Conditional skip (SKIPZ, SKIPNZ, SKIPC, SKIPNC) |
| 3 | Jump (JMP, JAL, RET) |
| 8 | Shift/Unary (SHL, SHR, ROL, ROR, INC, DEC, NOT, SWAP) |
| 3 | Pointer (INC16, DEC16, ADD16) |
| 8 | System (CLC, SEC, EI, DI, RTI, TRAP, NOP, HLT) |
| **68** | **Total instructions** |

All instructions are 2 bytes. 188 opcode slots remain free for future expansion.  
Undefined opcodes default to HLT (safe error behavior).

### Direct-Encoded Instruction Format

```
Byte 0: [unit(3)][op(3)][reg(2)]  — bits wire directly to hardware
         │         │       └── Register mux select (direct wire)
         │         └────────── ALU/shift operation (direct wire to ALU)
         └──────────────────── Functional unit enable (via 74HC138)

Byte 1: [immediate/offset/register/constant-select]
```

Minimal decode: 1× 74HC138 decodes unit select. Op bits and reg bits connect directly to hardware. No intermediate decode logic needed.

---

## 7. Cycle Timing

| Instruction type | Cycles | Breakdown |
|-----------------|--------|-----------|
| ALU / immediate / shift | 3 | Fetch0 + Fetch1 + Execute |
| Load/Store (ptr) | 4 | Fetch0 + Fetch1 + AddrSetup + MemAccess |
| Load/Store (ptr+) | 4 | Same + ptr increment (overlapped) |
| MOV / LI | 3 | Fetch0 + Fetch1 + Execute |
| Branch (not taken) | 3 | Fetch0 + Fetch1 + Evaluate |
| Branch (taken) | 4 | Fetch0 + Fetch1 + Evaluate + LoadPC |
| JMP (ptr) | 3 | Fetch0 + Fetch1 + LoadPC |
| JAL (ptr) | 6 | Fetch0 + Fetch1 + PushPCH + PushPCL + LoadPC |
| RET | 5 | Fetch0 + Fetch1 + PopPCL + PopPCH + LoadPC |
| PUSH | 4 | Fetch0 + Fetch1 + DecSP + Write |
| POP | 4 | Fetch0 + Fetch1 + Read + IncSP |

Average: ~3.5 cycles/instruction → **~571K instructions/sec at 2 MHz**

---

## 8. Assembly Examples

### Hello World
```asm
    li   ph, 0xC0       ; [0x13][0xC0] string in ROM
    li   pl, 0x80       ; [0x12][0x80] at 0xC080
loop:
    lb   a0, (ptr+)     ; [0x22][0x01] load char, ptr++
    cmpi a0, 0          ; [0x16][0x00] null terminator?
    beq  done           ; [0x30][0x06] skip 6 bytes ahead
    push a0             ; [0x28][0x01] save char
    li   ph, 0x80       ; [0x13][0x80] UART address
    li   pl, 0x00       ; [0x12][0x00]
    pop  a0             ; [0x29][0x01] restore char
    sb   a0, (ptr)      ; [0x21][0x01] write to UART
    bra  loop           ; [0x36][0xEC] branch back
done:
    hlt                 ; [0xFF][0x00]
```

### 16-bit Addition (A + B → C, all in RAM)
```asm
    ; Load A_low
    li   ph, 0x20       ; A at 0x2000
    li   pl, 0x00
    lb   a0, (ptr+)     ; a0 = A_low
    push a0
    lb   a0, (ptr)      ; a0 = A_high
    push a0
    ; Load B_low
    li   pl, 0x02       ; B at 0x2002
    lb   a0, (ptr+)     ; a0 = B_low
    mov  pl, a0         ; save B_low in pl temporarily
    pop  ph             ; ph = A_high (reuse reg)
    pop  a0             ; a0 = A_low
    ; Add low bytes
    clc
    add  pl             ; a0 = A_low + B_low (pl has B_low)
    ; ... (continue with carry into high byte)
```

### Game Loop (ZX Spectrum style)
```asm
; Clear screen — fill bitmap with 0
    li   ph, 0x00       ; video RAM starts at 0x0000
    li   pl, 0x00
    li   a0, 0x00       ; clear byte
clear:
    sb   a0, (ptr+)     ; write 0, advance pointer
    mov  a0, ph         ; check if we passed 0x1800
    cmpi a0, 0x18
    bne  clear

; Main game loop
game:
    ; Read input
    li   ph, 0x80
    li   pl, 0x41       ; GPIO input
    lb   a0, (ptr)      ; read buttons
    ; ... game logic ...
    ; Wait for frame
    bra  game
```

### Fibonacci (first 10 numbers)
```asm
    li   a0, 0          ; fib(0) = 0
    push a0
    li   a0, 1          ; fib(1) = 1
    li   sp, 10         ; counter (reuse sp briefly — careful!)
    ; Better: use memory for counter
    li   ph, 0x20
    li   pl, 0x00
    li   a0, 0
    sb   a0, (ptr+)     ; mem[0x2000] = 0
    li   a0, 1
    sb   a0, (ptr+)     ; mem[0x2001] = 1
    ; ... loop adding previous two
```

---

## 9. Hardwired Control Logic

Control is implemented with combinational 74HC logic (no microcode ROM).

### State Machine

2-bit state counter (74HC161): cycles through T0 → T1 → T2 → T3 → T0...

Some instructions complete at T2 (3 cycles), others need T3 (4 cycles).

### Group Decode (1× 74HC138)

```
opcode[7:4] → 74HC138 decoder:
  0x0_ = ALU group
  0x1_ = Immediate group
  0x2_ = Load/Store group
  0x3_ = Branch/Jump group
  0x4_ = Shift/Unary group
  0xF_ = System group
```

### Control Signal Equations

```
reg_we   = (T2) & (alu_grp | imm_grp | load_rd | pop | mov_to_rd)
mem_we   = (T3) & (store | push)
mem_rd   = (T0) | (T1) | (T2 & load_grp)
alu_src  = imm_grp
alu_op   = opcode[2:0]  (directly from instruction for ALU group)
flags_we = (T2) & (alu_grp | shift_grp | cmp | cmpi)
pc_inc   = (T0) | (T1)
pc_load  = (T2) & (branch_taken | jump)
ptr_inc  = (T3) & ptr_plus
addr_src = (T0|T1) ? PC : (load_grp|store_grp) ? PTR : (push|pop) ? STACK : PC
halt     = (T2) & (opcode == 0xFF)
```

### Hardware Implementation

| Chip | Type | Function |
|------|------|----------|
| 1× 74HC138 | 3-to-8 decoder | Decode opcode[7:4] → group |
| 1× 74HC139 | 2-to-4 decoder | Decode state[1:0] → T0,T1,T2,T3 |
| 2× 74HC08 | Quad AND | Combine group & state |
| 2× 74HC32 | Quad OR | Merge conditions |
| 1× 74HC04 | Hex inverter | NOT signals |
| 1× 74HC00 | Quad NAND | Branch condition eval |
| **8 chips total** | | **~200 gates, ~15 ns delay** |

### Advantages over Microcode ROM

- No speed limit (works at any clock up to 20+ MHz)
- No EEPROM programmer needed
- Students learn combinational logic design
- Cheaper ($5 vs $10)
- More educational (understand WHY each signal activates)

---

## 10. Video System

### Display Modes

| Mode | Resolution | Colors | VRAM used |
|------|-----------|--------|-----------|
| Graphics | 320×240, 1bpp bitmap | 16 (per 8×8 cell) | 9600 + 1000 = 10.6KB |
| Text | 40×25 characters | 16 fg + 16 bg per cell | 1000 + 1000 = 2KB |
| Mixed | Text overlay on graphics | Combined | 10.6KB + 1KB |

### VRAM Layout

```
Graphics bitmap: 320×240 / 8 = 9600 bytes (40 bytes per row × 240 rows)
  Address = row × 40 + col/8
  Bit position = 7 - (col % 8)

Attributes: 40×30 cells (one per 8×8 pixel block)
  Each byte: [paper 3:0][ink 3:0]
  16 colors (4-bit per foreground/background)

Text buffer: 40×25 characters (ASCII)
  Character ROM in video circuit provides 8×8 font
```

### 16-Color Palette

| Index | Color | R | G | B |
|-------|-------|---|---|---|
| 0 | Black | 0 | 0 | 0 |
| 1 | Dark Blue | 0 | 0 | 2 |
| 2 | Dark Red | 2 | 0 | 0 |
| 3 | Dark Magenta | 2 | 0 | 2 |
| 4 | Dark Green | 0 | 2 | 0 |
| 5 | Dark Cyan | 0 | 2 | 2 |
| 6 | Brown | 2 | 2 | 0 |
| 7 | Light Gray | 2 | 2 | 2 |
| 8 | Dark Gray | 1 | 1 | 1 |
| 9 | Blue | 0 | 0 | 3 |
| 10 | Red | 3 | 0 | 0 |
| 11 | Magenta | 3 | 0 | 3 |
| 12 | Green | 0 | 3 | 0 |
| 13 | Cyan | 0 | 3 | 3 |
| 14 | Yellow | 3 | 3 | 0 |
| 15 | White | 3 | 3 | 3 |

Color output: 2-bit R + 2-bit G + 2-bit B = 6 resistors (R-2R DAC per channel).

### Video Timing & Output

| Parameter | Value |
|-----------|-------|
| Resolution | 320×240 (pixel-doubled to 640×480 for VGA) |
| Pixel clock | 12.5 MHz |
| Refresh | 60 Hz |
| CPU contention | None (interleaved access: CPU on φ1, video on φ2) |

Dual output (simultaneous, same circuit):

| Output | Connector | Signal | Compatible with |
|--------|-----------|--------|-----------------|
| **VGA** | DE-15 | R,G,B analog (2-bit each) + H/V sync | VGA monitors, VGA→HDMI adapters |
| **Composite** | RCA jack | Combined video (resistor mix of RGB + sync) | TVs, capture cards |

Extra parts for dual output: VGA connector ($0.50) + 8 resistors ($0.15). Zero extra chips.

### Video Hardware

| Chip | Function | Count |
|------|----------|-------|
| 74HC161 | Address counter (row/col) | 3 |
| 74HC166 | Pixel shift register | 1 |
| 74HC157 | Color mux (ink/paper select) | 1 |
| AT28C64 | Character ROM (8×8 font, 256 chars) | 1 |
| 74HC74 | Sync generation flip-flops | 1 |
| 74HC138 | Mode/timing decode | 1 |
| **Total** | | **~8 chips** |

---

## 11. Sound System

### 8-bit D/A Sound

| Feature | Spec |
|---------|------|
| DAC resolution | 8-bit (256 levels) |
| Sample rate | Up to ~15 kHz (CPU-driven) or hardware timer |
| Output | Line-level audio (amplified to speaker) |
| Channels | 1 (mono) — software mixing for polyphony |
| Modes | Direct DAC (PCM samples) + tone generator |

### Hardware

| Part | Function | Cost |
|------|----------|------|
| R-2R ladder (8 resistors) | 8-bit DAC | $0.50 |
| LM386 | Audio amplifier | $1.00 |
| RC filter | Anti-aliasing (low-pass ~8kHz) | $0.20 |
| 555 timer (optional) | Hardware tone generator | $0.50 |
| **Total** | | **~$2.20** |

### Sound from BASIC

```basic
REM === Direct DAC (waveform) ===
10 FOR I = 0 TO 255
20   POKE &H8030, INT(SIN(I/40.5)*127+128)
30 NEXT I

REM === Tone generator ===
40 POKE &H8031, 220    : REM Frequency = 220 Hz (A3)
50 POKE &H8032, 3      : REM Enable tone + DAC
60 POKE &H8033, 200    : REM Volume

REM === Sound effect (assembly via USR for speed) ===
70 FOR F = 255 TO 1 STEP -1
80   POKE &H8030, F    : REM Falling pitch sweep
90 NEXT F
```

### Sound from Assembly (PCM playback)

```asm
; Play 8-bit PCM sample from memory
; Sample data at 0x4000, length in t0
    li   ph, 0x40       ; sample address high
    li   pl, 0x00       ; sample address low
play_loop:
    lb   a0, (ptr+)     ; load sample byte
    push a0             ; save
    li   ph, 0x80       ; I/O page
    li   pl, 0x30       ; DAC register
    pop  a0
    sb   a0, (ptr)      ; output to DAC
    ; delay loop for sample rate (~15kHz = ~133 cycles between samples)
    li   a0, 30
delay:
    dec  a0
    bne  delay
    ; restore pointer to sample data
    li   ph, 0x40       ; (would need to save/restore — simplified here)
    bra  play_loop
```

At 2 MHz: ~133 cycles between samples = ~15 kHz sample rate.  
Quality: telephone-grade (8-bit, 15kHz) — adequate for games and music.

---

## 12. Input Devices

### NES-style Digital Gamepads (×2)

```
NES Pad ──[serial clock/latch/data]──► 74HC165 (in pad) ──► CPU reads 8 bits
```

| Bit | Button |
|-----|--------|
| 7 | A |
| 6 | B |
| 5 | Select |
| 4 | Start |
| 3 | Up |
| 2 | Down |
| 1 | Left |
| 0 | Right |

Protocol: Write 1 then 0 to strobe (0x8042), then read 0x8040/0x8041.  
Hardware: Shift register inside each pad. No extra chips on motherboard.

```basic
10 POKE &H8042, 1 : POKE &H8042, 0  : REM Latch
20 P1 = PEEK(&H8040)                  : REM Read pad 1
30 IF P1 AND 8 THEN PRINT "UP"
40 IF P1 AND 128 THEN PRINT "A BUTTON"
```

### Analog Joysticks (×2)

Each joystick: 2 axes (X, Y) + buttons. ADC converts position to 0-255.

| Part | Function |
|------|----------|
| ADC0808 (or MCP3008) | 8-channel ADC, reads 4 axes + buttons |
| Joystick potentiometers | 10KΩ, 5V reference |

```basic
10 X1 = PEEK(&H8050)   : REM Joystick 1 X (0=left, 128=center, 255=right)
20 Y1 = PEEK(&H8051)   : REM Joystick 1 Y (0=up, 128=center, 255=down)
30 B1 = PEEK(&H8052)   : REM Buttons (bit 0=fire1, bit 1=fire2)
```

### Input Hardware Cost

| Device | Cost |
|--------|------|
| 2× NES gamepad clone | $6 |
| 2× Analog joystick | $8 |
| 1× ADC0808 | $3 |
| **Total** | **~$17** |

---

## 13. Comparison

| Feature | 6502 | RV8 v3 (breadboard) | RV8 v3 (PCB) | ZX Spectrum |
|---------|------|---------------------|--------------|-------------|
| Data width | 8-bit | 8-bit | 8-bit | 8-bit (Z80) |
| Instruction width | 1-3 bytes | 2 bytes fixed | 2 bytes fixed | 1-4 bytes |
| Registers | A, X, Y | a0, sp, pl, ph | same | A,B,C,D,E,H,L |
| Address bus | 16-bit | 16-bit | 16-bit | 16-bit |
| Clock | 1-2 MHz | **3.5 MHz** | **10 MHz** | 3.5 MHz |
| Video | varies | 320×240, 16 col | same | 256×192, 8 col |
| Sound | 1-bit | 8-bit DAC | same | 1-bit beeper |
| Input | keyboard | KB + 2 pads + 2 joy | same | KB + 1 joy |
| Gate count | ~3,500 | **~745** | ~745 | ~8,500 |
| Chip count | ~40 | **~22 (CPU)** | ~22 (CPU) | ~60 |
| Instr/sec | ~500K | **~1M** | **~2.8M** | ~1M |
| Decoupling caps | many | **3** | **7** | many |

---

*Next Phase: Architecture Design Document*
