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
for rd in range(8):
    # LI rd, imm (rd = 0 + imm)
    set_instruction(0b01_000_000 | rd, [
        ALUB_CLK,                           # step 2: B = operand
        ALUR_CLK | FLAGS_CLK,              # step 3: result = 0 + imm
        REG_WR_EN | END,                    # step 4: rd = result
    ])
    # ADDI rd, imm (rd = rd + imm)
    set_instruction(0b01_001_000 | rd, [
        ALUB_CLK,                           # step 2: B = operand
        ALUR_CLK | FLAGS_CLK,              # step 3: result = rd + imm
        REG_WR_EN | END,                    # step 4: rd = result
    ])
    # SUBI rd, imm (rd = rd - imm)
    set_instruction(0b01_010_000 | rd, [
        ALUB_CLK,                           # step 2: B = operand
        ALUR_CLK | FLAGS_CLK | ALU_SUB,    # step 3: result = rd - imm
        REG_WR_EN | END,                    # step 4: rd = result
    ])
    # ANDI rd, imm — NOT POSSIBLE with adder (skip for now)
    # ORI rd, imm — NOT POSSIBLE with adder (skip for now)
    # XORI rd, imm — NOT POSSIBLE with adder (skip for now)
    # SLTI rd, imm (rd = (rd < imm) ? 1 : 0) — use SUB + flag check
    set_instruction(0b01_110_000 | rd, [
        ALUB_CLK,                           # step 2: B = operand
        FLAGS_CLK | ALU_SUB,               # step 3: compute rd-imm, set flags (don't store)
        END,                                # step 4: done (flag_c = borrow = less than)
    ])
    # LUI rd, imm (rd = imm << 4) — simplified: just LI for now
    set_instruction(0b01_111_000 | rd, [
        ALUB_CLK,
        ALUR_CLK,
        REG_WR_EN | END,
    ])

# Class 00: ALU register (opcode = 00_ooo_ddd, operand[7:5]=rs)
for rd in range(8):
    # ADD rd, rd, rs
    set_instruction(0b00_000_000 | rd, [
        REG_RD_EN | ALUB_CLK,              # step 2: B = rs
        ALUR_CLK | FLAGS_CLK,              # step 3: result = rd + rs
        REG_WR_EN | END,                    # step 4: rd = result
    ])
    # SUB rd, rd, rs
    set_instruction(0b00_001_000 | rd, [
        REG_RD_EN | ALUB_CLK,
        ALUR_CLK | FLAGS_CLK | ALU_SUB,
        REG_WR_EN | END,
    ])
    # AND rd, rd, rs — can't do with adder, use microcode trick:
    # (skip — would need dedicated AND hardware)
    # OR rd, rd, rs — same
    # XOR rd, rd, rs — same
    # SLT rd, rd, rs (set less than)
    set_instruction(0b00_101_000 | rd, [
        REG_RD_EN | ALUB_CLK,
        FLAGS_CLK | ALU_SUB,               # compare only (don't store)
        END,
    ])
    # SLL rd (shift left = rd + rd)
    set_instruction(0b00_110_000 | rd, [
        ALUB_CLK,                           # B = rd (self, via operand trick... actually need rd on B)
        ALUR_CLK | FLAGS_CLK,              # result = rd + rd = shift left
        REG_WR_EN | END,
    ])
    # SRL rd (shift right — needs special hardware, skip for now)

# Class 10: Memory (opcode = 10_ooo_ddd)
for rd in range(8):
    # LB rd, off(rs) — load byte from memory
    # Step 2: compute address (rs + offset) — simplified: use operand as address directly
    set_instruction(0b10_000_000 | rd, [
        ADDR_CLK,                           # step 2: latch operand as addr_lo
        ADDR_HI,                            # step 3: latch high byte (from rs or zero)
        PC_ADDR & 0 | BUF_OE,             # step 4: addr latch drives, read memory
        ALUB_CLK,                           # step 5: data_in → ALU B
        ALUR_CLK,                           # step 6: result = 0 + data = data (pass through)
        REG_WR_EN | END,                    # step 7: rd = memory data
    ])
    # SB rd, off(rs) — store byte to memory
    set_instruction(0b10_001_000 | rd, [
        ADDR_CLK,                           # step 2: latch operand as addr_lo
        ADDR_HI,                            # step 3: latch high byte
        BUF_OE | BUF_DIR,                  # step 4: write rd to memory (rd drives data_out)
        END,                                # step 5: done
    ])
    # LB rd, [imm] (zero-page)
    set_instruction(0b10_010_000 | rd, [
        ADDR_CLK,                           # step 2: addr_lo = operand
        BUF_OE,                             # step 3: read from {0, operand}
        ALUB_CLK,                           # step 4: data → ALU B
        ALUR_CLK,                           # step 5: pass through
        REG_WR_EN | END,                    # step 6: rd = data
    ])
    # SB rd, [imm] (zero-page)
    set_instruction(0b10_011_000 | rd, [
        ADDR_CLK,                           # step 2: addr_lo = operand
        BUF_OE | BUF_DIR,                  # step 3: write rd to {0, operand}
        END,                                # step 4: done
    ])
    # PUSH rd
    set_instruction(0b10_100_000 | rd, [
        ADDR_CLK,                           # step 2: addr = sp (simplified)
        BUF_OE | BUF_DIR,                  # step 3: write rd to stack
        END,                                # step 4: done (sp-- handled separately)
    ])
    # POP rd
    set_instruction(0b10_101_000 | rd, [
        ADDR_CLK,                           # step 2: addr = sp
        BUF_OE,                             # step 3: read from stack
        ALUB_CLK,                           # step 4: data → ALU B
        ALUR_CLK,                           # step 5: pass through
        REG_WR_EN | END,                    # step 6: rd = data (sp++ handled separately)
    ])

# Class 11: Branch/Jump/System (opcode = 11_ooo_ddd)
for rd in range(8):
    # BEQ — branch if Z=1
    set_branch(0b11_000_000 | rd, take_on_z=1)
    # BNE — branch if Z=0
    set_branch(0b11_001_000 | rd, take_on_z=0)
    # BCS — branch if C=1
    set_branch(0b11_010_000 | rd, take_on_c=1)
    # BCC — branch if C=0
    set_branch(0b11_011_000 | rd, take_on_c=0)
    # JAL rd, off (rd = PC, PC += off)
    set_instruction(0b11_100_000 | rd, [
        PC_LOAD | END,                      # step 2: PC += operand (simplified)
    ])
    # JALR rd, rs (PC = rs)
    set_instruction(0b11_101_000 | rd, [
        PC_LOAD | END,                      # step 2: PC = rs (simplified)
    ])
    # J off (unconditional jump)
    set_instruction(0b11_110_000 | rd, [
        PC_LOAD | END,                      # step 2: PC += off
    ])
    # SYS (NOP/HLT)
    set_instruction(0b11_111_000 | rd, [END])

# === Fill unused with END (safe default) ===
for i in range(ROM_SIZE):
    if ucode[i] == 0:
        ucode[i] = FETCH_OP  # default: try to fetch (safe)

# === OUTPUT ===
with open("microcode.hex", "w") as f:
    for i in range(ROM_SIZE):
        f.write(f"{ucode[i]:04x}\n")

print(f"Generated microcode.hex ({ROM_SIZE} entries)")
print(f"Instructions: LI, ADDI, SUBI, SLTI, LUI, ADD, SUB, SLT, SLL")
print(f"              LB, SB, LB_ZP, SB_ZP, PUSH, POP")
print(f"              BEQ, BNE, BCS, BCC, JAL, JALR, J, SYS")
