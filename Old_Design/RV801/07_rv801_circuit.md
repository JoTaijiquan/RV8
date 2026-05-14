# RV801 — Circuit Diagrams (A & B variants)

**Same ISA as RV8 (68 instructions). Same programs. Just slower and fewer chips.**

---

## RV801-A: 8 CPU chips + EEPROM microcode

```
┌─────────────────────────────────────────────────────────┐
│                    RV801-A (11 chips total)              │
│                                                         │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐         │
│  │ U1   │ │ U2   │ │ U3   │ │ U4   │ │ U5   │         │
│  │161   │ │161   │ │595   │ │153   │ │ 74   │         │
│  │PC lo │ │PC hi │ │Accum │ │ALU   │ │Flags │         │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘         │
│                                                         │
│  ┌──────┐ ┌──────┐ ┌──────┐                            │
│  │ U6   │ │ U7   │ │ U8   │                            │
│  │161   │ │28C16 │ │245   │                            │
│  │State │ │uCode │ │BusBuf│                            │
│  └──────┘ └──────┘ └──────┘                            │
│                                                         │
│  ┌──────┐ ┌──────┐ ┌──────┐                            │
│  │ U9   │ │ U10  │ │ U11  │                            │
│  │28C256│ │62256 │ │ 138  │                            │
│  │ ROM  │ │ RAM  │ │Decode│                            │
│  └──────┘ └──────┘ └──────┘                            │
└─────────────────────────────────────────────────────────┘
```

### Chip List (RV801-A)

| # | Part | Function | Pins |
|---|------|----------|:----:|
| U1 | 74HC161 | PC low (4-bit counter, cascaded) | 16 |
| U2 | 74HC161 | PC high (4-bit counter, cascaded) | 16 |
| U3 | 74HC595 | Accumulator (8-bit shift register) | 16 |
| U4 | 74HC153 | 1-bit ALU (dual 4:1 mux) | 16 |
| U5 | 74HC74 | Flags: Carry + Zero + NMI latch | 14 |
| U6 | 74HC161 | Micro-step counter (0-15) | 16 |
| U7 | AT28C16 | Microcode ROM (2K×8) | 24 |
| U8 | 74HC245 | Data bus buffer | 20 |
| U9 | AT28C256 | Program ROM (32KB) | 28 |
| U10 | 62256 | RAM (32KB) | 28 |
| U11 | 74HC138 | Address decode | 16 |

### How it works

```
Every instruction:
  1. Micro-step counter (U6) counts 0→15
  2. Microcode ROM (U7) addressed by {opcode[7:4], step[3:0]}
  3. ROM output drives control signals directly
  4. Accumulator (U3) shifts 1 bit per step through ALU (U4)
  5. After 8 shifts = 1 ALU operation complete
  6. Counter resets, next instruction fetches

Bit-serial ALU:
  U4 (74HC153) selects: A+B, A&B, A|B, A^B
  One bit computed per clock cycle
  Carry stored in U5 flip-flop between bits
```

### Microcode ROM (U7) Programming

```
Address [7:0] = {opcode[7:4], micro_step[3:0]}
Data [7:0] = control signals:
  Bit 0: shift_acc (shift accumulator)
  Bit 1: alu_sel0 (ALU operation select)
  Bit 2: alu_sel1
  Bit 3: mem_rd (read memory)
  Bit 4: mem_wr (write memory)
  Bit 5: pc_inc (increment PC)
  Bit 6: addr_src (0=PC, 1=computed)
  Bit 7: done (reset step counter, next instruction)
```

### Connections

```
U1.TC → U2.ENT (PC carry chain)
U6.Q[3:0] → U7.A[3:0] (step → ROM address low)
U5.Q (opcode latch from bus) → U7.A[7:4] (opcode → ROM address high)
U7.D[7:0] → control signals (directly drive chip enables)
U3.SER_IN ← U4.Y (ALU result bit feeds accumulator)
U3.Q7 → U4.input (accumulator MSB feeds back to ALU)
U8 bridges internal/external data bus
```

---

## RV801-B: 9 CPU chips, no EEPROM

```
┌─────────────────────────────────────────────────────────┐
│                    RV801-B (12 chips total)              │
│                                                         │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐         │
│  │ U1   │ │ U2   │ │ U3   │ │ U4   │ │ U5   │         │
│  │161   │ │161   │ │595   │ │153   │ │ 74   │         │
│  │PC lo │ │PC hi │ │Accum │ │ALU   │ │Flags │         │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘         │
│                                                         │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                   │
│  │ U6   │ │ U7   │ │ U8   │ │ U9   │                   │
│  │161   │ │138   │ │ 00   │ │245   │                   │
│  │State │ │Decode│ │NAND  │ │BusBuf│                   │
│  └──────┘ └──────┘ └──────┘ └──────┘                   │
│                                                         │
│  ┌──────┐ ┌──────┐ ┌──────┐                            │
│  │ U10  │ │ U11  │ │ U12  │                            │
│  │28C256│ │62256 │ │ 138  │                            │
│  │ ROM  │ │ RAM  │ │Decode│                            │
│  └──────┘ └──────┘ └──────┘                            │
└─────────────────────────────────────────────────────────┘
```

### Chip List (RV801-B)

| # | Part | Function | Pins |
|---|------|----------|:----:|
| U1 | 74HC161 | PC low (4-bit counter) | 16 |
| U2 | 74HC161 | PC high (4-bit counter) | 16 |
| U3 | 74HC595 | Accumulator (8-bit shift register) | 16 |
| U4 | 74HC153 | 1-bit ALU (dual 4:1 mux) | 16 |
| U5 | 74HC74 | Flags: Carry + Zero | 14 |
| U6 | 74HC161 | Phase counter (2-bit) + bit counter (3-bit) | 16 |
| U7 | 74HC138 | Phase decode (FETCH/EXEC/WRITE) | 16 |
| U8 | 74HC00 | NAND gates (signal generation) | 14 |
| U9 | 74HC245 | Data bus buffer | 20 |
| U10 | AT28C256 | Program ROM (32KB) | 28 |
| U11 | 62256 | RAM (32KB) | 28 |
| U12 | 74HC138 | Address decode | 16 |

### How it works (no EEPROM)

```
U6 counter: bits[1:0] = phase (FETCH=0, EXEC=1, WRITE=2)
            bits[3:2] = bit counter (0-7 for serial ALU)

U7 (74HC138) decodes phase:
  /Y0 = FETCH phase active
  /Y1 = EXECUTE phase active
  /Y2 = WRITE phase active

U8 (74HC00 NAND gates) generates control signals:
  Gate 1: mem_rd = FETCH AND NOT(write)
  Gate 2: pc_inc = FETCH AND bit_done
  Gate 3: shift_acc = EXECUTE
  Gate 4: done = WRITE AND bit7 (all 8 bits processed)
```

---

## Comparison

| | RV801-A | RV801-B |
|--|:-------:|:-------:|
| CPU chips | 8 | 9 |
| System total | 11 | 12 |
| Control | EEPROM (programmable) | Logic gates (fixed) |
| Needs programmer | Yes | No |
| Flexibility | Re-burn to change | Rewire to change |
| Speed | ~175K instr/s | ~175K instr/s |
| Cost | ~$16 | ~$14 |
| Best for | Schools with programmer | Anyone, anywhere |

---

## Registers (both variants)

Registers live in RAM (zero-page), not in hardware:

| RAM addr | Register | Purpose |
|:--------:|----------|---------|
| 0x00 | sp | Stack pointer |
| 0x01 | a0 | Accumulator shadow |
| 0x02 | pl | Pointer low |
| 0x03 | ph | Pointer high |
| 0x04 | t0 | Temporary |
| 0x05 | pg | Page register |
| 0x06 | c1 | Constant 0x01 |
| 0x07 | cn | Constant 0xFF |
| 0x08 | ch | Constant 0x80 |

The microcode/logic reads/writes these RAM addresses to "access registers."
Only the accumulator (U3, shift register) is a hardware register.

---

## Memory Map (same as RV8)

```
0x0000–0x00FF  Zero page (registers + fast globals)
0x0100–0x2FFF  RAM
0x3000–0x30FF  Stack
0x3100–0x7FFF  Free RAM
0x8000–0x80FF  I/O
0xC000–0xFFFF  ROM (32KB)
0xFFFC–0xFFFD  Reset vector
```

---

## Build Notes

### RV801-A (with EEPROM):
1. Build U1-U6, U8 on breadboard (7 chips)
2. Program AT28C16 with microcode table (use TL866 programmer)
3. Insert U7 (EEPROM)
4. Add ROM, RAM, decode (U9-U11)
5. Load test program into ROM
6. Power on → CPU runs

### RV801-B (no EEPROM):
1. Build U1-U6 on breadboard (6 chips)
2. Wire U7 (138) and U8 (00) for control logic
3. Add U9 (bus buffer)
4. Add ROM, RAM, decode (U10-U12)
5. Power on → CPU runs
6. No programmer needed — just wire and go

---

## Upgrade Path

```
RV801-A/B (1 breadboard, $14-16)
     │ same ROM, same programs
     ▼
RV8 (4 breadboards, $21)
     │ add peripheral board
     ▼
Full Computer (video, sound, keyboard)
```
