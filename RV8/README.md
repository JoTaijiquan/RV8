# RV8 — 8-bit RISC-V Style CPU

**27 logic chips. 8 registers. RISC-V syntax. Flash microcode. ~1.25 MIPS @ 10 MHz.**

---

## Specs

| Parameter | Value |
|-----------|-------|
| Logic chips | 27 (+ ROM + RAM = 29 total) |
| Gates | ~765 |
| Registers | 8 (r0=zero, r1=ra, r2=a0, r3=a1, r4=t0, r5=t1, r6=s0, r7=sp) |
| ISA | ~35 instructions, RISC-V style (~95% syntax match) |
| Control | SST39SF010A Flash microcode (70ns, PDIP-32) |
| Data path | 8-bit, single internal bus |
| Address | 16-bit (64KB) |
| Clock | 3.5 MHz (breadboard) / 10 MHz (PCB) |
| MIPS | ~1.25 @ 10 MHz (8 steps max) |
| Runs | BASIC, video games |

---

## ISA Summary (RISC-V look and feel)

### ALU Register-Register
```
ADD  rd, rd, rs      # rd = rd + rs
SUB  rd, rd, rs      # rd = rd - rs
AND  rd, rd, rs      # rd = rd & rs
OR   rd, rd, rs      # rd = rd | rs
XOR  rd, rd, rs      # rd = rd ^ rs
SLT  rd, rd, rs      # rd = (rd < rs) ? 1 : 0
SLL  rd              # rd = rd << 1
SRL  rd              # rd = rd >> 1
```

### ALU Immediate
```
LI   rd, imm         # rd = imm
ADDI rd, imm         # rd = rd + imm
SUBI rd, imm         # rd = rd - imm
ANDI rd, imm         # rd = rd & imm
ORI  rd, imm         # rd = rd | imm
XORI rd, imm         # rd = rd ^ imm
SLTI rd, imm         # rd = (rd < imm) ? 1 : 0
LUI  rd, imm         # rd = imm << 4
```

### Load/Store (RISC-V style)
```
LB   rd, off(rs)     # rd = mem[rs + offset]
SB   rd, off(rs)     # mem[rs + offset] = rd
PUSH rd              # sp--, mem[sp] = rd
POP  rd              # rd = mem[sp], sp++
```

### Branch/Jump (register-compare, no visible flags)
```
BEQ  rs1, rs2, off   # branch if rs1 == rs2
BNE  rs1, rs2, off   # branch if rs1 != rs2
BLT  rs1, rs2, off   # branch if rs1 < rs2
BGE  rs1, rs2, off   # branch if rs1 >= rs2
JAL  rd, off         # rd = PC+2, jump to PC+off
JALR rd, rs          # rd = PC+2, jump to rs
SYS  imm             # NOP/HLT/ECALL
```

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  8 Registers (574×8) ←→ INTERNAL BUS (8-bit)│
│  ALU (283×2 + 86×2)  ←→ INTERNAL BUS       │
│  PC (574×2, /OE)     ←→ ADDRESS BUS        │
│  Addr Latch (574×2)  ←→ ADDRESS BUS        │
│  Bus Buffer (245)     ←→ ROM/RAM DATA      │
│  Flash Microcode      →  ALL control signals│
└─────────────────────────────────────────────┘
```

---

## Status

- ✅ Design document
- ✅ ISA reference (RISC-V aligned)
- ✅ Verilog model (19/21 pass, minor fix pending)
- ✅ WiringGuide (verified buildable, no bus conflicts)
- ✅ Understand_by_Module.md (student guide)
- ⬜ Microcode table generator
- ⬜ Assembler
- ⬜ Build guide (labs)
- ⬜ Physical build

---

## Files

```
RV8/
├── README.md              ← this file
├── rv8_cpu.v            ← Verilog behavioral model
├── tb/tb_rv8_cpu.v      ← testbench
└── doc/
    ├── 00_design.md       ← architecture + chip list
    ├── 01_isa_reference.md← full ISA (RISC-V style)
    ├── WiringGuide.md     ← pin-level wiring (verified)
    └── Understand_by_Module.md ← 6 modules for students
```
