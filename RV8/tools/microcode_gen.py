#!/usr/bin/env python3
"""RV8 Microcode Generator — generates microcode.hex for Flash ROM"""

# Control word bits (16-bit)
BUF_OE    = 1 << 0
BUF_DIR   = 1 << 1
PC_ADDR   = 1 << 2
ADDR_CLK  = 1 << 3
PC_INC    = 1 << 4
IR_CLK    = 1 << 5
OPR_CLK   = 1 << 6
STEP_RST  = 1 << 7
REG_RD_EN = 1 << 8
REG_WR_EN = 1 << 9
ALUB_CLK  = 1 << 10
ALUR_CLK  = 1 << 11
ALU_SUB   = 1 << 12
FLAGS_CLK = 1 << 13
PC_LOAD   = 1 << 14
ADDR_HI   = 1 << 15

# Fetch sequence (same for all instructions)
FETCH_OP  = PC_ADDR | BUF_OE | IR_CLK | PC_INC          # step 0: read opcode
FETCH_OPR = PC_ADDR | BUF_OE | OPR_CLK | PC_INC         # step 1: read operand

# End of instruction
END = STEP_RST

# Microcode ROM: 16K entries (14-bit address)
# Address = {irq_n(1), flag_c(1), flag_z(1), step(3), opcode(8)}
ROM_SIZE = 16384
ucode = [0] * ROM_SIZE

def addr(opcode, step, z=0, c=0, irq=1):
    """Calculate microcode ROM address"""
    return (irq << 13) | (c << 12) | (z << 11) | (step << 8) | opcode

def set_instruction(opcode, steps, flags_matter=False):
    """Set microcode for an instruction (all flag combinations)"""
    for irq in [0, 1]:
        for c in [0, 1]:
            for z in [0, 1]:
                # Step 0 and 1 are always fetch
                a = addr(opcode, 0, z, c, irq)
                ucode[a] = FETCH_OP
                a = addr(opcode, 1, z, c, irq)
                ucode[a] = FETCH_OPR
                # Steps 2+ from the provided sequence
                for s, ctrl in enumerate(steps):
                    a = addr(opcode, s + 2, z, c, irq)
                    ucode[a] = ctrl

def set_branch(opcode, take_on_z=None, take_on_c=None):
    """Set microcode for branch instruction (flag-dependent)"""
    for irq in [0, 1]:
        for c in [0, 1]:
            for z in [0, 1]:
                # Fetch always same
                ucode[addr(opcode, 0, z, c, irq)] = FETCH_OP
                ucode[addr(opcode, 1, z, c, irq)] = FETCH_OPR
                
                # Determine if branch taken
                taken = False
                if take_on_z is not None:
                    taken = (z == take_on_z)
                if take_on_c is not None:
                    taken = (c == take_on_c)
                
                if taken:
                    # Branch taken: load PC from operand (PC + offset)
                    # Step 2: compute PC + offset (operand is signed offset)
                    ucode[addr(opcode, 2, z, c, irq)] = ALUB_CLK | ALUR_CLK | END
                    # Simplified: just set PC_LOAD + END
                    # Actually need: ALU computes PC+offset... complex
                    # For now: PC_LOAD uses ir_opr as offset added to PC
                    ucode[addr(opcode, 2, z, c, irq)] = PC_LOAD | END
                else:
                    # Branch not taken: just end
                    ucode[addr(opcode, 2, z, c, irq)] = END

# === DEFINE ISA ===

# Class 01: Immediate (opcode = 01_ooo_ddd)
# LI rd, imm: rd = imm (pass through ALU as 0 + imm)
for rd in range(8):
    op = 0b01_000_000 | rd  # LI
    set_instruction(op, [
        ALUB_CLK,                           # step 2: latch operand into ALU B
        ALUR_CLK | FLAGS_CLK,              # step 3: compute 0+imm, latch result
        REG_WR_EN | END,                    # step 4: write to rd
    ])

# ADDI rd, imm: rd = rd + imm
for rd in range(8):
    op = 0b01_001_000 | rd  # ADDI
    set_instruction(op, [
        ALUB_CLK,                           # step 2: ALU B = operand (imm)
        ALUR_CLK | FLAGS_CLK,              # step 3: ALU computes rd + imm, latch result
        REG_WR_EN | END,                    # step 4: write to rd
    ])

# SUBI rd, imm: rd = rd - imm
for rd in range(8):
    op = 0b01_010_000 | rd  # SUBI
    set_instruction(op, [
        ALUB_CLK,                           # step 2: ALU B = operand
        ALUR_CLK | FLAGS_CLK | ALU_SUB,    # step 3: rd - imm
        REG_WR_EN | END,                    # step 4: write
    ])

# Class 00: ALU register (opcode = 00_ooo_ddd, operand[7:5]=rs)
# ADD rd, rd, rs
for rd in range(8):
    op = 0b00_000_000 | rd  # ADD
    set_instruction(op, [
        REG_RD_EN | ALUB_CLK,              # step 2: rs → ALU B latch
        ALUR_CLK | FLAGS_CLK,              # step 3: rd + rs, latch result
        REG_WR_EN | END,                    # step 4: write to rd
    ])

# SUB rd, rd, rs
for rd in range(8):
    op = 0b00_001_000 | rd  # SUB
    set_instruction(op, [
        REG_RD_EN | ALUB_CLK,
        ALUR_CLK | FLAGS_CLK | ALU_SUB,
        REG_WR_EN | END,
    ])

# Class 11: Control
# BEQ (opcode = 11_000_ddd) — branch if Z=1
for rd in range(8):
    op = 0b11_000_000 | rd
    set_branch(op, take_on_z=1)

# BNE (opcode = 11_001_ddd) — branch if Z=0
for rd in range(8):
    op = 0b11_001_000 | rd
    set_branch(op, take_on_z=0)

# SYS (opcode = 11_111_ddd) — HLT when operand=$01
for rd in range(8):
    op = 0b11_111_000 | rd
    set_instruction(op, [END])  # just end (HLT = loop on step 0)

# NOP
set_instruction(0b11_100_000, [END])

# === Fill unused with END (safe default) ===
for i in range(ROM_SIZE):
    if ucode[i] == 0:
        ucode[i] = FETCH_OP  # default: try to fetch (safe)

# === OUTPUT ===
with open("microcode.hex", "w") as f:
    for i in range(ROM_SIZE):
        f.write(f"{ucode[i]:04x}\n")

print(f"Generated microcode.hex ({ROM_SIZE} entries)")
print(f"Instructions defined: LI, ADDI, SUBI, ADD, SUB, BEQ, BNE, NOP, HLT")
