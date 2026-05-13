# RV808 — Architecture (Detailed Design)

---

## 1. Memory Map

### Code Space (fetched by PC, internal)

```
$0000-$3FFF  ROM bank 0 (16KB) — system, always present
$4000-$7FFF  ROM bank 1 OR RAM (16KB) — switchable via RAM_EXEC bit
```

ROM banking: ROM_BANK bits (from U15/U16) → ROM A15+ for larger ROMs.

### Data Space (accessed via page:offset, external bus to on-board RAM)

```
Pages $00-$3F  Data-only RAM (16KB)
  $00:         Zero-page variables (256 bytes)
  $01:         Stack (256 bytes)
  $02-$05:     Screen buffer (1KB, 40×25 + attributes)
  $06-$07:     Tile/sprite defs (512 bytes)
  $08-$1F:     BASIC program text (6KB)
  $20-$3F:     Free data (8KB)

Pages $40-$7F  Code+Data RAM (16KB, same physical RAM as code overlay)
  Executable programs live here
  Also accessible as data (self-modifying OK)

Pages $80-$FF  External bus (expansion slots + I/O)
  $80-$8F:     Slot 1 (4KB)
  $90-$9F:     Slot 2 (4KB)
  $A0-$AF:     Slot 3 (4KB)
  $B0-$BF:     Slot 4 (4KB)
  $F0-$FF:     System I/O (keyboard, video, sound, SD, UART)
```

### Physical RAM mapping:

```
62256 (32KB) address pins:
  A[14:8] ← page latch [6:0] (data access) OR PC[14:8] (code fetch)
  A[7:0]  ← bus A[7:0] (data access) OR PC[7:0] (code fetch)
  
  Data page $00 = RAM address $0000
  Data page $3F = RAM address $3FFF
  Data page $40 = RAM address $4000 = Code address $4000
  Data page $7F = RAM address $7FFF = Code address $7FFF
```

---

## 2. Register Set

| Register | Width | Encoding | Purpose |
|----------|:-----:|:--------:|---------|
| a0 | 8 | 00 | Accumulator (ALU destination) |
| t0 | 8 | 01 | Temporary / index |
| sp | 8 | 10 | Stack pointer (stack at page $01) |
| pg | 8 | 11 | Page register (drives page latch) |

### Constant generator (c0, virtual):

When register source = c0 (encoding depends on opcode):
- bits [1:0] = 00 → 0x00
- bits [1:0] = 01 → 0x01
- bits [1:0] = 10 → 0xFF
- bits [1:0] = 11 → 0x80

No physical register — just decode logic.

---

## 3. Instruction Encoding

### Format: [opcode 8-bit] [operand 8-bit]

```
opcode[7:5] = unit (8 groups)
opcode[4:0] = operation + modifiers

Unit 0 (000): ALU register    — ADD, SUB, AND, OR, XOR, CMP, ADC, SBC
Unit 1 (001): ALU immediate   — ADDI, SUBI, CMPI, ANDI, ORI, XORI, TST
Unit 2 (010): Load/Store      — LB, SB (pg:imm, pg:t0, zp, sp+imm)
Unit 3 (011): Branch          — BEQ, BNE, BCS, BCC, BMI, BPL, BRA
Unit 4 (100): Shift/Unary     — SHL, SHR, ROL, ROR, INC, DEC, NOT, SWAP
Unit 5 (101): Load Immediate  — LI a0/t0/sp/pg (= PAGE)
Unit 6 (110): Stack/Jump      — PUSH, POP, JAL, RET
Unit 7 (111): System          — SKIP, EI, DI, TRAP, RTI, NOP, HLT, CLC, SEC
```

### Unit 2 detail (Load/Store):

```
opcode[4:3] = address mode:
  00 = pg:imm    — address = {pg, operand}
  01 = pg:t0     — address = {pg, t0}
  10 = zp:imm    — address = {$00, operand}
  11 = sp+imm    — address = {$01, sp + operand}

opcode[2] = direction:
  0 = Load (LB)
  1 = Store (SB)

opcode[1:0] = (reserved / destination for loads)
```

### Unit 5 detail (Load Immediate):

```
opcode[1:0] = destination register:
  00 = LI a0, imm
  01 = LI t0, imm
  10 = LI sp, imm
  11 = LI pg, imm  (= PAGE imm — also pulses /PG_WR)
```

---

## 4. Instruction List (~60 instructions)

### ALU Register (Unit 0): 8 instructions

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| $00 | ADD t0 | a0 ← a0 + t0 |
| $01 | SUB t0 | a0 ← a0 - t0 |
| $02 | AND t0 | a0 ← a0 & t0 |
| $03 | OR t0 | a0 ← a0 \| t0 |
| $04 | XOR t0 | a0 ← a0 ^ t0 |
| $05 | CMP t0 | flags ← a0 - t0 (no store) |
| $06 | ADC t0 | a0 ← a0 + t0 + C |
| $07 | SBC t0 | a0 ← a0 - t0 - !C |

### ALU Immediate (Unit 1): 7 instructions

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| $20 | ADDI imm | a0 ← a0 + imm |
| $21 | SUBI imm | a0 ← a0 - imm |
| $22 | CMPI imm | flags ← a0 - imm |
| $23 | ANDI imm | a0 ← a0 & imm |
| $24 | ORI imm | a0 ← a0 \| imm |
| $25 | XORI imm | a0 ← a0 ^ imm |
| $26 | TST imm | flags ← a0 & imm |

### Load/Store (Unit 2): 8 instructions

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| $40 | LB pg:imm | a0 ← RAM[{pg, imm}] |
| $44 | SB pg:imm | RAM[{pg, imm}] ← a0 |
| $48 | LB pg:t0 | a0 ← RAM[{pg, t0}] |
| $4C | SB pg:t0 | RAM[{pg, t0}] ← a0 |
| $50 | LB zp:imm | a0 ← RAM[{$00, imm}] |
| $54 | SB zp:imm | RAM[{$00, imm}] ← a0 |
| $58 | LB sp+imm | a0 ← RAM[{$01, sp+imm}] |
| $5C | SB sp+imm | RAM[{$01, sp+imm}] ← a0 |

### Branch (Unit 3): 7 instructions

| Opcode | Mnemonic | Condition |
|--------|----------|-----------|
| $60 | BEQ off | Z=1 |
| $61 | BNE off | Z=0 |
| $62 | BCS off | C=1 |
| $63 | BCC off | C=0 |
| $64 | BMI off | N=1 |
| $65 | BPL off | N=0 |
| $66 | BRA off | always |

offset = signed 8-bit, PC = PC + 2 + sign_extend(offset)

### Shift/Unary (Unit 4): 8 instructions

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| $80 | SHL | a0 ← a0 << 1, C ← a0[7] |
| $81 | SHR | a0 ← a0 >> 1, C ← a0[0] |
| $82 | ROL | a0 ← {a0[6:0], C}, C ← a0[7] |
| $83 | ROR | a0 ← {C, a0[7:1]}, C ← a0[0] |
| $84 | INC | a0 ← a0 + 1 |
| $85 | DEC | a0 ← a0 - 1 |
| $86 | NOT | a0 ← ~a0 |
| $87 | SWAP | a0 ← {a0[3:0], a0[7:4]} |

### Load Immediate (Unit 5): 4 instructions

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| $A0 | LI a0, imm | a0 ← imm |
| $A1 | LI t0, imm | t0 ← imm |
| $A2 | LI sp, imm | sp ← imm |
| $A3 | PAGE imm | pg ← imm, pulse /PG_WR |

### Stack/Jump (Unit 6): 6 instructions

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| $C0 | PUSH a0 | sp--, RAM[{$01,sp}] ← a0 |
| $C1 | PUSH t0 | sp--, RAM[{$01,sp}] ← t0 |
| $C2 | POP a0 | a0 ← RAM[{$01,sp}], sp++ |
| $C3 | POP t0 | t0 ← RAM[{$01,sp}], sp++ |
| $C4 | JAL imm | push PC, PC ← {0, imm} or {pg, imm} |
| $C5 | RET | pop PC |

### System (Unit 7): 12 instructions

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| $E0 | NOP | no operation |
| $E1 | HLT | halt (wake on interrupt) |
| $E2 | EI | IE ← 1 |
| $E3 | DI | IE ← 0 |
| $E4 | CLC | C ← 0 |
| $E5 | SEC | C ← 1 |
| $E6 | TRAP | software interrupt |
| $E7 | RTI | return from interrupt |
| $E8 | SKIPZ | skip next if Z=1 |
| $E9 | SKIPNZ | skip next if Z=0 |
| $EA | SKIPC | skip next if C=1 |
| $EB | SKIPNC | skip next if C=0 |

### Total: **60 instructions**

---

## 5. State Machine

### States (10 states):

```
F0:  Fetch opcode — ROM/RAM[PC] → IR_opcode, PC++
F1:  Fetch operand — ROM/RAM[PC] → IR_operand, PC++
EX:  Execute — ALU/register/branch (combinational)
M1:  Memory read — A=offset, /RD, D→register
M2:  Memory write — A=offset, D←register, /WR
PG:  Page write — D←pg, /PG_WR pulse
S1:  Stack push — sp--, A=sp, D←data, /WR
S2:  Stack pop — A=sp, /RD, D→reg, sp++
S3:  Push PCH (for JAL/interrupt)
S4:  Push PCL (for JAL/interrupt)
```

### Instruction timing:

| Type | Sequence | Cycles |
|------|----------|:------:|
| ALU/shift/MOV/NOP | F0,F1,EX | 3 |
| LI a0/t0/sp | F0,F1,EX | 3 |
| PAGE (LI pg) | F0,F1,EX+PG | 3 |
| Branch (not taken) | F0,F1,EX | 3 |
| Branch (taken) | F0,F1,EX | 3* |
| LB (any mode) | F0,F1,EX,M1 | 4 |
| SB (any mode) | F0,F1,EX,M2 | 4 |
| PUSH | F0,F1,S1 | 3 |
| POP | F0,F1,S2 | 3 |
| JAL | F0,F1,S3,S4,EX | 5 |
| RET | F0,F1,S2,S2,EX | 5 |
| TRAP | F0,F1,S3,S4,S1,EX | 6 |
| RTI | F0,F1,S2,S2,S2,EX | 6 |
| SKIP (true) | F0,F1,EX,F0,F1 | 5 |

*Branch taken: PC loaded in EX, next fetch from new address (no penalty if PC load is fast)

### Average: ~3.5 cycles/instruction

---

## 6. Datapath

```
┌─────────────────────────────────────────────────────────┐
│                                                          │
│   ROM ──────────────────────────────┐                   │
│   RAM (code overlay) ───────────────┤                   │
│                                     ▼                   │
│                              ┌────────────┐             │
│   PC[14:0] ────────────────→│ ROM/RAM    │             │
│   (74HC161 ×4)              │ data out   │             │
│                              └─────┬──────┘             │
│                                    │                    │
│                                    ▼                    │
│                    ┌──────────────────────────┐         │
│                    │     IR (U5, U6)          │         │
│                    │  opcode[7:0] operand[7:0]│         │
│                    └──────┬───────────┬───────┘         │
│                           │           │                 │
│         ┌─────────────────┘           │                 │
│         ▼                             ▼                 │
│  ┌─────────────┐              ┌─────────────┐          │
│  │   DECODE    │              │  OPERAND    │          │
│  │   (U14)    │              │  → ALU B    │          │
│  │   + control│              │  → A[7:0]   │          │
│  └──────┬──────┘              └──────┬──────┘          │
│         │                            │                  │
│         ▼                            ▼                  │
│  ┌─────────────────────────────────────────────┐       │
│  │              INTERNAL BUS (8-bit)            │       │
│  │  a0  t0  sp  pg  ALU_out  operand  const   │       │
│  └───┬────┬────┬────┬────┬──────────────────────┘       │
│      │    │    │    │    │                              │
│      ▼    ▼    ▼    ▼    ▼                              │
│  ┌──────────────────────────────┐                       │
│  │         ALU (U11-U13)        │                       │
│  │  A input ← a0 (always)      │                       │
│  │  B input ← operand/reg/const│                       │
│  │  result → a0 or data_out    │                       │
│  └──────────────────────────────┘                       │
│                                                          │
│  ┌──────────────────────────────┐                       │
│  │  PAGE LATCH (U20)            │                       │
│  │  pg value → RAM A[15:8]     │                       │
│  └──────────────────────────────┘                       │
│                                                          │
│  ┌──────────────────────────────┐                       │
│  │  RAM (62256)                  │                       │
│  │  A[14:8] ← page_latch[6:0] │  (data access)        │
│  │       OR ← PC[14:8]         │  (code fetch)         │
│  │  A[7:0]  ← offset           │  (from operand/t0/sp) │
│  │       OR ← PC[7:0]          │  (code fetch)         │
│  │  D[7:0]  ↔ internal bus     │                       │
│  └──────────────────────────────┘                       │
│                                                          │
│  ┌──────────────────────────────┐                       │
│  │  BUS BUFFER (U19, 74HC245)   │                       │
│  │  internal ↔ external D[7:0] │  (for I/O/expansion)  │
│  └──────────────────────────────┘                       │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 7. Control Signals

| Signal | Source | Purpose |
|--------|--------|---------|
| ir_clk0 | U17 (AND) | Latch opcode into U5 |
| ir_clk1 | U17 (AND) | Latch operand into U6 |
| reg_wr[1:0] | decode | Select register to write (a0/t0/sp/pg) |
| reg_wr_en | control | Enable register write |
| alu_op[3:0] | decode | ALU operation select |
| alu_src | decode | ALU B source (operand/register/const) |
| mem_rd | control | Assert /RD to RAM |
| mem_wr | control | Assert /WR to RAM |
| pg_wr | control | Pulse /PG_WR (update page latch) |
| addr_src[1:0] | control | A[7:0] source: operand/t0/sp |
| pc_load | control | Load PC (branch/jump) |
| pc_inc | control | Increment PC |
| sp_inc | control | sp ← sp + 1 |
| sp_dec | control | sp ← sp - 1 |
| ram_exec | U15/U16 bit | Fetch from RAM instead of ROM at $4000+ |
| rom_bank | U15/U16 bit | Select ROM bank |
| flags_wr | control | Update Z/C/N flags |
| skip_flag | U16 | Suppress next instruction |
| bus_dir | control | 74HC245 direction (read/write) |
| bus_en | control | 74HC245 /OE |
| slot_sel[1:0] | U21 | Which expansion slot is active |

---

## 8. Interrupt Handling

### Vectors (in ROM, fixed):

```
$3FF8: TRAP vector (2 bytes)
$3FFA: NMI vector (2 bytes)
$3FFC: RESET vector (2 bytes)
$3FFE: IRQ vector (2 bytes)
```

### Sequence (NMI/IRQ):

```
1. Finish current instruction
2. Push PCH → stack
3. Push PCL → stack
4. Push flags → stack
5. DI (disable interrupts)
6. PC ← vector address (from ROM)
7. Fetch from new PC (handler in ROM)
```

### Handler in ROM dispatches to user code:

```asm
; ROM IRQ handler at vector address:
irq_handler:
    PUSH a0
    PUSH t0
    ; ... handle interrupt ...
    ; optionally jump to user handler in RAM:
    ; LB zp:USER_IRQ_VEC  ; read user vector from zero-page
    ; ... indirect call ...
    POP t0
    POP a0
    RTI
```

---

## 9. Boot Sequence

```
1. /RST asserts → all registers clear, PC ← $0000 (or read RESET vector)
2. ROM at $0000 starts executing:
   - Initialize sp ($FF)
   - Initialize pg ($00)
   - Clear screen buffer
   - Initialize I/O devices
   - Print "RV808 READY"
   - Enter BASIC interpreter or command monitor
```

---

## 10. Timing Diagram (10 MHz)

```
Clock period: 100ns

Fetch opcode (F0):
  0ns:   PC drives ROM address
  50ns:  ROM data valid (AT28C256: 150ns... need faster ROM at 10MHz)
  100ns: IR_opcode latches on rising edge, PC increments

For 10 MHz: use SST39SF010 (70ns) or W27C512 (45ns)
For 3.5 MHz: AT28C256 (150ns) works fine (period = 286ns)
```

---

## 11. BOM Cost Estimate

| Part | Qty | Unit price | Total |
|------|:---:|:----------:|:-----:|
| 74HC161 | 4 | $0.30 | $1.20 |
| 74HC574 | 7 | $0.35 | $2.45 |
| 74HC283 | 2 | $0.50 | $1.00 |
| 74HC86 | 1 | $0.25 | $0.25 |
| 74HC138 | 2 | $0.30 | $0.60 |
| 74HC74 | 2 | $0.25 | $0.50 |
| 74HC08 | 1 | $0.25 | $0.25 |
| 74HC32 | 1 | $0.25 | $0.25 |
| 74HC245 | 1 | $0.35 | $0.35 |
| AT28C256 | 1 | $3.00 | $3.00 |
| 62256 | 1 | $1.50 | $1.50 |
| Crystal osc | 1 | $0.50 | $0.50 |
| Misc (caps, resistors, LEDs) | — | — | $2.00 |
| Breadboard ×3 | 3 | $3.00 | $9.00 |
| **Total** | | | **~$23** |
