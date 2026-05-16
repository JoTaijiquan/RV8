# RV8 Microcode Control Word Definition

## Flash Address (14 bits → 16K entries):
```
A[7:0]  = opcode (from IR, U9)
A[10:8] = step counter (from U26, 0-7)
A[11]   = flag_z
A[12]   = flag_c
A[13]   = /IRQ
```

## Control Word (16 bits, from U23 + U27):

### U23 outputs (D[7:0]) — Bus & Memory control:
```
Bit 0: BUF_OE     — enable external bus buffer (U22, active HIGH)
Bit 1: BUF_DIR    — buffer direction (0=read ext→IBUS, 1=write IBUS→ext)
Bit 2: PC_ADDR    — PC drives address bus (1=fetch mode, 0=addr latch mode)
Bit 3: ADDR_CLK   — latch IBUS into address register (rising edge)
Bit 4: PC_INC     — increment PC
Bit 5: IR_CLK     — latch IBUS into IR opcode register
Bit 6: OPR_CLK    — latch IBUS into IR operand register
Bit 7: STEP_RST   — reset step counter to 0 (end of instruction)
```

### U27 outputs (D[7:0]) — ALU & Register control:
```
Bit 0: REG_RD_EN  — enable register read onto IBUS (U20 G1)
Bit 1: REG_WR_EN  — enable register write from ALU_R (U21 G1)
Bit 2: ALUB_CLK   — latch IBUS into ALU B register
Bit 3: ALUR_CLK   — latch ALU output into result register
Bit 4: ALU_SUB    — subtract mode (XOR invert + carry=1)
Bit 5: FLAGS_CLK  — latch flags (Z, C) from ALU
Bit 6: PC_LOAD    — load PC from ALU result (for branch/jump)
Bit 7: ADDR_HI_CLK— latch IBUS into address high register
```

## Register select (from operand bits, active during REG_RD_EN / REG_WR_EN):
- Read select: operand[7:5] (rs field) → U20 (138) A,B,C
- Write select: opcode[2:0] (rd field) → U21 (138) A,B,C

## Micro-step sequences:

### FETCH (all instructions start with this):
```
Step 0: PC_ADDR=1, BUF_OE=1, BUF_DIR=0, IR_CLK=1, PC_INC=1
        → ROM[PC] → IBUS → IR latches opcode, PC++
Step 1: PC_ADDR=1, BUF_OE=1, BUF_DIR=0, OPR_CLK=1, PC_INC=1
        → ROM[PC] → IBUS → operand latches, PC++
```

### ADDI rd, imm (class 01, op 001):
```
Step 2: REG_RD_EN=1 (rd drives IBUS via U20, using opcode[2:0])
        ALUB_CLK=1 (latch IBUS into ALU B — this is rd value!)
        Wait — we want rd + imm. Need rd on ALU A and imm on ALU B.
        
Actually: ALU A comes from IBUS (rd drives it).
          ALU B comes from operand register (imm).
          But ALU B latch needs to hold the operand...
          
Revised:
Step 2: OPR drives ALUB (operand register /OE → ALUB bus)
        REG_RD_EN=1 (rd → IBUS → ALU A input)
        ALU computes: A + B = rd + imm
        ALUR_CLK=1 (latch result)
        FLAGS_CLK=1
Step 3: REG_WR_EN=1 (result → rd via U21)
        STEP_RST=1 (done, back to step 0)
```

Hmm — this assumes ALU A comes from IBUS and ALU B from operand simultaneously. That works if they're on separate buses (IBUS for A, ALUB bus for B). Which matches the WiringGuide design!

### Simplified step sequences:

| Instruction | Steps | Sequence |
|-------------|:-----:|----------|
| ADDI rd, imm | 4 | fetch(2) + compute+write(2) |
| ADD rd, rd, rs | 5 | fetch(2) + load_rs(1) + compute+write(2) |
| LI rd, imm | 3 | fetch(2) + write_imm(1) |
| LB rd, off(rs) | 6 | fetch(2) + addr_setup(2) + mem_read(1) + write(1) |
| SB rd, off(rs) | 6 | fetch(2) + addr_setup(2) + mem_write(1) + done(1) |
| BEQ rs1,rs2,off | 5 | fetch(2) + load_rs(1) + compare(1) + branch(1) |
| JAL rd, off | 4 | fetch(2) + save_PC(1) + jump(1) |
