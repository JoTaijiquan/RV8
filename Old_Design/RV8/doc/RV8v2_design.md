# RV8 v2 — RISC-V Inspired, Microcode Control

**22 chips. 8 registers. Load/Store architecture. Flash microcode.**

---

## 1. Philosophy

Simple hardware + smart microcode = powerful ISA.

- Hardware is just: registers, ALU, bus, PC. No mux, no complex decode.
- Microcode (in Flash) sequences the hardware through multi-cycle operations.
- ISA is RISC-V inspired: register-to-register, load/store only, uniform encoding.

---

## 2. Registers (8 × 74HC574)

| Reg | Name | Convention |
|:---:|------|-----------|
| r0 | zero | Always 0 (hardwired or microcode enforced) |
| r1 | a0 | Return value / accumulator |
| r2 | a1 | Argument 1 |
| r3 | t0 | Temporary |
| r4 | t1 | Temporary |
| r5 | s0 | Saved |
| r6 | s1 | Saved |
| r7 | sp | Stack pointer |

All general-purpose. r0=0 by convention (microcode never writes to r0).

---

## 3. Instruction Format

```
[opcode 8-bit] [operand 8-bit]

opcode[7:6] = class (00=ALU, 01=IMM, 10=MEM, 11=CTL)
opcode[5:3] = operation within class
opcode[2:0] = rd (destination register)

operand = immediate value OR {rs1[2:0], rs2[2:0], xx}
```

### Class 00: ALU register-register

```
opcode = [00][op3][rd3]
operand = [rs1_3][rs2_3][00]

rd = rd OP rs2  (rs1 = rd implicitly, like RISC-V compressed)
```

| op[5:3] | Mnemonic | Operation |
|:-------:|----------|-----------|
| 000 | ADD rd, rs | rd ← rd + rs |
| 001 | SUB rd, rs | rd ← rd - rs |
| 010 | AND rd, rs | rd ← rd & rs |
| 011 | OR rd, rs | rd ← rd \| rs |
| 100 | XOR rd, rs | rd ← rd ^ rs |
| 101 | SLT rd, rs | rd ← (rd < rs) ? 1 : 0 |
| 110 | SHL rd | rd ← rd << 1 |
| 111 | SHR rd | rd ← rd >> 1 |

### Class 01: Immediate

```
opcode = [01][op3][rd3]
operand = imm8
```

| op[5:3] | Mnemonic | Operation |
|:-------:|----------|-----------|
| 000 | LI rd, imm | rd ← imm |
| 001 | ADDI rd, imm | rd ← rd + imm |
| 010 | SUBI rd, imm | rd ← rd - imm |
| 011 | ANDI rd, imm | rd ← rd & imm |
| 100 | ORI rd, imm | rd ← rd \| imm |
| 101 | XORI rd, imm | rd ← rd ^ imm |
| 110 | CMPI rd, imm | flags ← rd - imm (no store) |
| 111 | LUI rd, imm | rd ← imm << 4 (upper nibble load) |

### Class 10: Memory (Load/Store only)

```
opcode = [10][op3][rd3]
operand = offset8 (signed)
```

| op[5:3] | Mnemonic | Operation |
|:-------:|----------|-----------|
| 000 | LB rd, [rs+off] | rd ← mem[rs + sign_ext(off)] (rs from operand[7:5]) |
| 001 | SB rd, [rs+off] | mem[rs + sign_ext(off)] ← rd |
| 010 | LB rd, [imm] | rd ← mem[{0, imm}] (zero-page) |
| 011 | SB rd, [imm] | mem[{0, imm}] ← rd (zero-page) |
| 100 | PUSH rd | sp--, mem[sp] ← rd |
| 101 | POP rd | rd ← mem[sp], sp++ |
| 110 | LW rd, [sp+off] | rd ← mem[sp + off] (stack local) |
| 111 | SW rd, [sp+off] | mem[sp + off] ← rd (stack local) |

### Class 11: Control

```
opcode = [11][op3][cond/rd]
operand = offset8 or address
```

| op[5:3] | Mnemonic | Operation |
|:-------:|----------|-----------|
| 000 | BEQ off | branch if Z=1 |
| 001 | BNE off | branch if Z=0 |
| 010 | BCS off | branch if C=1 |
| 011 | BCC off | branch if C=0 |
| 100 | JAL rd, off | rd ← PC, PC ← PC + off |
| 101 | JALR rd, rs | rd ← PC, PC ← rs (indirect) |
| 110 | RET | PC ← r1 (or pop from stack) |
| 111 | SYS | NOP/HLT/EI/DI/TRAP (sub-decoded by operand) |

---

## 4. Hardware Architecture

```
┌─────────────────────────────────────────────────────┐
│                  INTERNAL BUS (8-bit)                 │
├──────┬──────┬──────┬──────┬──────┬──────┬──────────┤
│  r0  │  r1  │  r2  │  r3  │  r4  │  r5  │ r6 │ r7 │
│  574 │  574 │  574 │  574 │  574 │  574 │ 574│ 574│
├──────┴──────┴──────┴──────┴──────┴──────┴────┴─────┤
│                                                      │
│  ┌────────┐  ┌────────┐  ┌────────┐                │
│  │  ALU   │  │   PC   │  │   IR   │                │
│  │283+86  │  │4×161   │  │2×574   │                │
│  └────────┘  └────────┘  └────────┘                │
│                                                      │
│  ┌────────────────────────────────────────────┐     │
│  │  CONTROL FLASH (SST39SF010A-70)            │     │
│  │  Address: {state, opcode, flags}           │     │
│  │  Data: all control signals                 │     │
│  └────────────────────────────────────────────┘     │
│                                                      │
│  ┌────────┐  ┌────────┐                            │
│  │Bus Buf │  │Reg Sel │                            │
│  │  245   │  │  138   │                            │
│  └────────┘  └────────┘                            │
└──────────────────────────┬──────────────────────────┘
                           │ 40-pin bus
                    ROM + RAM + I/O
```

### Key insight: ONE internal bus

Everything shares one 8-bit bus. Microcode sequences transfers:
1. Enable source register onto bus (/OE)
2. Clock destination register (CLK)
3. Repeat for next step

This means each instruction takes multiple micro-steps, but hardware is minimal.

---

## 5. Chip List (22 chips)

| U# | Chip | Function |
|:--:|------|----------|
| U1-U8 | 74HC574 ×8 | Registers r0-r7 (all have /OE for bus drive) |
| U9-U10 | 74HC574 ×2 | IR opcode + operand |
| U11-U12 | 74HC283 ×2 | ALU adder (8-bit) |
| U13 | 74HC86 | XOR (SUB + logic ops) |
| U14-U17 | 74HC161 ×4 | PC (16-bit counter) |
| U18 | 74HC245 | External bus buffer |
| U19 | 74HC138 | Register select (3-to-8, chooses which reg drives bus) |
| U20 | SST39SF010A | Control microcode Flash (70ns, PDIP-32) |
| — | AT28C256 | Program ROM |
| — | 62256 | Data RAM |
| **Total** | | **22 chips (20 logic + ROM + RAM)** |

### How register select works:

```
U19 (74HC138): A,B,C = reg_sel[2:0] from microcode
  /Y0 → U1./OE (r0 drives bus)
  /Y1 → U2./OE (r1 drives bus)
  ...
  /Y7 → U8./OE (r7 drives bus)

Only ONE register drives the bus at a time.
Destination register CLK comes from separate microcode output.
```

### How ALU works:

```
Micro-step 1: source reg → bus → ALU input latch (temp)
Micro-step 2: dest reg → bus → ALU input A
Micro-step 3: ALU computes, result → bus → dest reg CLK
```

ALU A input = always from bus (latched).
ALU B input = from bus (latched in previous step).
Result goes back to bus → destination register.

Needs: 1× 74HC574 as ALU temp latch. That's already counted in the 8 registers (r0 can serve as temp, or add U_temp).

Actually: need **1 more 574** for ALU B latch. → **23 chips**.

---

## 6. Revised: 23 chips

| Added | Why |
|-------|-----|
| +1× 74HC574 (ALU B latch) | Hold second operand while ALU computes |

**Final: 23 chips.** Still fewer than RV8 v1 (27+) and RV8-G (27).

---

## 7. Microcode State Machine

Each instruction takes 4-8 micro-steps:

```
Step 0: PC → address bus, read ROM → data bus → IR opcode, PC++
Step 1: PC → address bus, read ROM → data bus → IR operand, PC++
Step 2: reg[rs] → bus → ALU_B latch
Step 3: reg[rd] → bus → ALU_A (direct wire)
Step 4: ALU result → bus → reg[rd] CLK
Step 5: (done, back to step 0)
```

For memory access (LB/SB):
```
Step 2: reg[rs] → bus → address low latch
Step 3: compute address high
Step 4: read/write memory
Step 5: data → reg[rd]
```

Microcode Flash address = {state[3:0], opcode[7:0], flags[1:0]} = 14 bits = 16K entries.
Each entry = 8 bits of control signals.

With 2 Flash chips (or 1 chip, 2 banks): 16 control signals available. Enough for:
- reg_sel[2:0] (which reg drives bus)
- reg_clk[2:0] (which reg latches from bus)
- alu_op[2:0]
- pc_inc, pc_ld
- mem_rd, mem_wr
- addr_latch
- next_state[3:0]

---

## 8. Performance

| Parameter | Value |
|-----------|-------|
| Clock | 10 MHz (PCB) / 3.5 MHz (breadboard) |
| Micro-steps per instruction | 4-8 (avg ~5) |
| Instructions/sec @ 10 MHz | **2.0M** |
| Instructions/sec @ 3.5 MHz | 700K |
| BASIC lines/sec | ~560 |

---

## 9. Comparison

| | RV8 v1 | RV8 v2 | RV8-G |
|--|:---:|:---:|:---:|
| Chips | 31 (honest) | **23** | 27 |
| Registers | 7 (special) | **8 (general)** | 5 |
| ISA | Accumulator (68) | **Register-register (40)** | Accumulator (30) |
| Control | Flash | Flash | Pure gates |
| MIPS @ 10 MHz | 4.0 | **2.0** | 2.5 |
| Hardware complexity | **High** | **Low** | Medium |
| Programmer needed | Yes | Yes | No |
| RISC-V style | No | **Yes** | No |
| Buildable (honest) | ❌ (WiringGuide incomplete) | ✅ (simple bus) | ✅ |

---

## 10. Why This Works

The single-bus architecture means:
- **No address mux** — microcode puts address on bus, then latches it
- **No ALU B mux** — microcode loads B latch first, then computes
- **No register decode gates** — 74HC138 + /OE does all selection
- **No complex control** — Flash generates everything

The ONLY chips are: registers + ALU + PC + bus buffer + decode + Flash.

**22-23 chips. Fully buildable. Every pin traceable. RISC-V inspired.**
