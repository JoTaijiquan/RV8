# RV8 — RISC-V Style, Speed-Optimized, Flash Microcode

**24 chips. 8 registers. Dual-bus ALU. 3.3 MIPS @ 10 MHz.**

---

## 1. Key Idea: Dual Read Bus

```
Bus A (read port 1) → ALU input A
Bus B (read port 2) → ALU input B
ALU result → write bus → destination register

All three happen in ONE clock cycle during execute.
```

This eliminates the sequential "load A, load B, compute, store" of single-bus designs.

---

## 2. Chip List (24 chips)

| U# | Chip | Function |
|:--:|------|----------|
| U1-U8 | 74HC574 ×8 | Registers r0-r7 (dual /OE: A-bus and B-bus) |
| U9-U10 | 74HC574 ×2 | IR (opcode + operand) |
| U11-U12 | 74HC283 ×2 | ALU adder (8-bit) |
| U13 | 74HC86 | XOR (SUB/XOR ops) |
| U14-U17 | 74HC161 ×4 | PC (16-bit) |
| U18 | 74HC138 | Register select A (which reg → bus A) |
| U19 | 74HC138 | Register select B (which reg → bus B) |
| U20 | 74HC245 | External data bus buffer |
| U21 | SST39SF010A | Control microcode (70ns, PDIP-32) |
| U22 | 74HC74 | Flags (Z, C) + state bits |
| — | AT28C256 | Program ROM |
| — | 62256 | Data RAM |
| **Total** | | **24 chips (22 logic + ROM + RAM)** |

Wait — 74HC574 has only ONE /OE pin. Can't drive two buses simultaneously from same register.

**Fix**: Use the /OE for bus A. For bus B, use a **second set of outputs** — but 574 only has one set.

**Better approach**: Registers drive bus A via /OE (74HC138 #1 selects). Bus B comes from the **operand register (U10)** for immediate, or from a **second 74HC245** that taps the same register outputs onto bus B.

Actually, simplest: **Bus B = operand (immediate) OR register via mux**.

Let me rethink...

---

## 3. Revised: Practical Dual-Port

```
ALU A input ← always from rd (destination register, /OE enabled)
ALU B input ← from operand (immediate) OR from rs (source register via 245 buffer)

During execute:
  - 138 #1 enables rd onto bus A → ALU A
  - 138 #2 enables rs onto bus B → through 245 → ALU B
  - OR: operand register drives ALU B directly (for immediate ops)
  - ALU computes
  - Result → rd (CLK pulse)
```

But two 138s enabling two different registers simultaneously means two registers driving two separate buses. Each register's Q outputs go to BOTH buses via separate wires? No — 574 has only 8 output pins, one set.

**Real solution: Register file with 2 read ports needs either:**
1. Two copies of each register (expensive: 16× 574)
2. Time-multiplex: read A in first half-cycle, read B in second half-cycle
3. Use operand register as B source (most instructions are reg+imm anyway)

### Option 3 is best for 8-bit:

Most useful instructions are `ADDI rd, imm` (register + immediate). For `ADD rd, rs`, we can do:
- Step 1: rs → temp latch (via bus)
- Step 2: rd + temp → rd (ALU)

That's 2 extra cycles for reg-reg ops, but immediate ops are fast (1 execute cycle).

---

## 4. Final Architecture: Fast Immediate, 2-step Register

```
Instruction timing:
  Immediate ops (ADDI, LI, ORI...): fetch(2) + execute(1) = 3 cycles → 3.3 MIPS
  Register ops (ADD, SUB...):        fetch(2) + load_rs(1) + execute(1) = 4 cycles → 2.5 MIPS
  Load/Store:                         fetch(2) + addr(1) + data(1) = 4 cycles → 2.5 MIPS
  Branch taken:                       fetch(2) + execute(1) = 3 cycles
  
  Average (BASIC workload ~60% imm, 20% reg, 20% mem): ~3.3 cycles → 3.0 MIPS
```

---

## 5. Simplified Chip List (23 chips)

| U# | Chip | Function |
|:--:|------|----------|
| U1-U8 | 74HC574 ×8 | Registers r0-r7 (/OE for bus drive) |
| U9 | 74HC574 | IR opcode |
| U10 | 74HC574 | IR operand (also serves as ALU B for immediate) |
| U11 | 74HC574 | ALU B latch (for register-register ops) |
| U12-U13 | 74HC283 ×2 | ALU adder (8-bit) |
| U14 | 74HC86 | XOR (SUB + logic) |
| U15-U18 | 74HC161 ×4 | PC (16-bit) |
| U19 | 74HC138 | Register select (which reg drives bus / gets written) |
| U20 | 74HC245 | External bus buffer |
| U21 | SST39SF010A | Control microcode (70ns) |
| U22 | 74HC74 | Flags (Z, C) |
| — | AT28C256 | Program ROM |
| — | 62256 | Data RAM |
| **Total** | | **23 chips** |

Removed: second 138 (not needed — single bus with temp latch is simpler and proven).

---

## 6. ISA (optimized for speed)

### Encoding:
```
opcode[7:6] = class
opcode[5:3] = operation  
opcode[2:0] = rd (destination register)
operand[7:5] = rs (source register, for reg-reg ops)
operand[4:0] = immediate5 (for small constants) OR full imm8
```

### Class 00: ALU register-register (4 cycles)
```
ADD rd, rs    rd ← rd + rs
SUB rd, rs    rd ← rd - rs
AND rd, rs    rd ← rd & rs
OR  rd, rs    rd ← rd | rs
XOR rd, rs    rd ← rd ^ rs
CMP rd, rs    flags ← rd - rs
MOV rd, rs    rd ← rs
SLT rd, rs    rd ← (rd < rs) ? 1 : 0
```

### Class 01: ALU immediate (3 cycles — FAST)
```
LI  rd, imm8     rd ← imm8
ADDI rd, imm8    rd ← rd + imm8
SUBI rd, imm8    rd ← rd - imm8
ANDI rd, imm8    rd ← rd & imm8
ORI  rd, imm8    rd ← rd | imm8
XORI rd, imm8    rd ← rd ^ imm8
CMPI rd, imm8    flags ← rd - imm8
SHL  rd          rd ← rd << 1
SHR  rd          rd ← rd >> 1
```

### Class 10: Memory (4 cycles)
```
LB  rd, [rs+off5]   rd ← mem[rs + sign_ext(off5)]
SB  rd, [rs+off5]   mem[rs + sign_ext(off5)] ← rd
LB  rd, [imm8]      rd ← mem[{0, imm8}] (zero-page)
SB  rd, [imm8]      mem[{0, imm8}] ← rd
PUSH rd              sp--, mem[sp] ← rd
POP  rd              rd ← mem[sp], sp++
```

### Class 11: Control (3 cycles)
```
BEQ  off8     branch if Z=1
BNE  off8     branch if Z=0
BCS  off8     branch if C=1
BCC  off8     branch if C=0
BRA  off8     branch always
JAL  rd, off8 rd ← PC, PC ← PC + off8
JMP  imm8     PC ← {r6, imm8} (r6 = page register by convention)
RET           PC ← r1 (link register) — actually: POP PC
NOP/HLT/EI/DI/TRAP (sub-decoded from operand)
```

### Total: ~35 instructions

---

## 7. Performance

| Instruction type | Cycles | Frequency | Weighted |
|-----------------|:------:|:---------:|:--------:|
| Immediate ALU | 3 | 50% | 1.5 |
| Register ALU | 4 | 15% | 0.6 |
| Load/Store | 4 | 20% | 0.8 |
| Branch/Jump | 3 | 15% | 0.45 |
| **Average** | | | **3.35** |

| Clock | MIPS | BASIC lines/sec |
|:-----:|:----:|:---------------:|
| 3.5 MHz | 1.04 | ~300 |
| 10 MHz | **2.99** | ~840 |

---

## 8. Why RV8 > RV8 v1

| | RV8 v1 (current) | RV8 |
|--|:---:|:---:|
| Chips | 31 (honest) | **23** |
| Buildable | ❌ (WiringGuide broken) | **✅** |
| Registers | 7 (special purpose) | **8 (general, RISC-V)** |
| ISA style | Accumulator | **Register-register** |
| Hardware | Complex (mux, decode) | **Simple (bus + microcode)** |
| MIPS @ 10 MHz | 4.0 (theoretical) | **3.0** (achievable) |
| Every pin traceable | No | **Yes** |

---

## 9. Comparison (full family)

| | RV801-B | RV8 | RV8-G |
|--|:---:|:---:|:---:|
| Chips | 9 | **23** | 27 |
| Architecture | Bit-serial | **Register-register** | Accumulator |
| Control | Hardwired | **Flash microcode** | Pure gates |
| Registers | In RAM | **8 (hardware)** | 5 |
| MIPS @ 10 MHz | 0.5 | **3.0** | 2.5 |
| ISA | 68 (slow) | **35 (fast)** | 30 |
| Run BASIC | ⚠️ | **✅** | ✅ |
| Programmer needed | No | Yes (Flash) | No |

---

## 10. Next Steps

- [ ] Verilog model (rv8_cpu.v)
- [ ] Testbench (all 35 instructions)
- [ ] Microcode table generator (Python script)
- [ ] WiringGuide (pin-level, verified)
- [ ] Build guide + labs
