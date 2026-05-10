# RV8 — Architecture Design

**Project**: RV8 Minimal Educational CPU  
**Version**: 1.0  
**Date**: 2026-05-11  
**Phase**: 3 — Architecture

---

## 1. Block Diagram

```
                          ┌─────────────────────────────────────────┐
                          │              ADDRESS BUS (16-bit)        │
                          └──┬────────┬────────┬────────┬───────────┘
                             │        │        │        │
                    ┌────────▼──┐  ┌──▼────┐  ┌▼──────┐ │
                    │    PC     │  │ PTR   │  │ STACK │ │  ADDR MUX
                    │  (16-bit) │  │{ph,pl}│  │{30,sp}│ │  selects source
                    └────────┬──┘  └──┬────┘  └┬──────┘ │
                             │        │        │        │
                             └────────┴────────┴────────┘
                                         │
                          ┌──────────────▼──────────────────────────┐
                          │              DATA BUS (8-bit)            │
                          └──┬──────┬──────┬──────┬──────┬──────────┘
                             │      │      │      │      │
                    ┌────────▼┐  ┌──▼───┐  │  ┌───▼──┐  │
                    │   IR    │  │ REG  │  │  │ ALU  │  │
                    │(16-bit) │  │ FILE │  │  │(8-bit│  │
                    │op+operand│  │sp,a0,│  │  │ +flags│  │
                    └────┬────┘  │pl,ph,│  │  └───┬──┘  │
                         │       │t0,pg │  │      │     │
                         │       └──┬───┘  │      │     │
                         │          │      │      │     │
                    ┌────▼──────────▼──────▼──────▼─────▼───────────┐
                    │           CONTROL UNIT                         │
                    │   Direct-encoded FSM + prefetch logic          │
                    │   Inputs: IR opcode, flags, state              │
                    │   Outputs: all control signals                 │
                    └───────────────────────────────────────────────┘
```

---

## 2. Datapath

### 2.1 Data Flow

```
Memory ──► Data Bus ──► IR (byte 0 = opcode, byte 1 = operand)
                    ──► Register File (write)
                    ──► ALU input B
                    
Register File ──► ALU input A (always a0 for ALU ops)
              ──► Data Bus (for store operations)
              ──► Address Bus low (pl, sp)
              ──► Address Bus high (ph, pg, 0x30, 0x00)

ALU ──► Data Bus ──► Register File (write back to a0)
    ──► Flags (Z, C, N)

PC ──► Address Bus (during fetch)
   ◄── PC + 2 (normal increment)
   ◄── PC + offset (branch taken)
   ◄── {ph, pl} (jump indirect)
   ◄── Vector address (interrupt)
```

### 2.2 Address Bus Sources

| Source | High byte | Low byte | Used by |
|--------|-----------|----------|---------|
| PC | PC[15:8] | PC[7:0] | Instruction fetch |
| Pointer | ph | pl | LB/SB (ptr), (ptr+) |
| Stack | 0x30 (fixed) | sp | PUSH, POP, JAL, RET |
| Stack-relative | 0x30 (fixed) | sp + imm8 | LB/SB [sp+imm] |
| Zero-page | 0x00 (fixed) | imm8 | LB/SB [zp+imm] |
| Page-relative | pg | imm8 | LB/SB [pg:imm] |
| Vector | 0xFF | vector_lo | Interrupt/TRAP entry |

### 2.3 ALU Operations

| alu_op[2:0] | Operation | Output |
|:-----------:|-----------|--------|
| 000 | ADD | A + B + Cin |
| 001 | SUB | A - B - !Cin |
| 010 | AND | A & B |
| 011 | OR | A \| B |
| 100 | XOR | A ^ B |
| 101 | SHL | {A[6:0], 0} |
| 110 | SHR | {0, A[7:1]} |
| 111 | PASS_B | B (passthrough for LI/MOV) |

Flags set: Z = (result == 0), C = carry/borrow out, N = result[7]

---

## 3. Control FSM

### 3.1 States

```
         ┌──────────────────────────────────────────┐
         │                                          │
         ▼                                          │
    ┌─────────┐     ┌─────────┐     ┌─────────┐    │
    │   S0    │────►│   S1    │────►│   S2    │────┘ (most instructions)
    │ FETCH0  │     │ FETCH1  │     │ EXECUTE │
    │         │     │+EXECUTE │     │ (mem    │
    │ addr=PC │     │ prev    │     │  access)│
    │ read mem│     │ instr   │     │         │
    │ →prefetch     │         │     │         │
    └─────────┘     └─────────┘     └─────────┘
                                         │
                                         │ (JAL/RET need more)
                                         ▼
                                    ┌─────────┐
                                    │   S3    │
                                    │ STACK   │
                                    │ push/pop│
                                    └────┬────┘
                                         │
                                         ▼
                                    ┌─────────┐
                                    │   S4    │
                                    │ STACK2  │
                                    │ (JAL:   │
                                    │  push   │
                                    │  2nd    │
                                    │  byte)  │
                                    └─────────┘
```

### 3.2 Fetch/Execute Overlap Timing

```
Clock:    ──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──┐  ┌──
            └──┘  └──┘  └──┘  └──┘  └──┘  └──┘

State:    │ S0  │ S1  │ S0  │ S1  │ S0  │ S1  │
          │     │     │     │     │     │     │

Action:   │FETCH│FETCH│FETCH│FETCH│FETCH│FETCH│
          │op[0]│op[1]│op[0]│op[1]│op[0]│op[1]│
          │     │+EXEC│     │+EXEC│     │+EXEC│
          │     │instr│     │instr│     │instr│
          │     │ [0] │     │ [1] │     │ [2] │

Instr:    │◄─ instr 0 ─►│◄─ instr 1 ─►│◄─ instr 2 ─►│
          │  2 cycles   │  2 cycles   │  2 cycles   │
```

**Most instructions: 2 cycles.** S0 fetches opcode, S1 fetches operand AND executes previous instruction simultaneously.

For memory-access instructions (LB, SB, PUSH, POP): need S2 for the data memory access (bus is busy).

### 3.3 Cycle Count (with overlap)

| Instruction type | States used | Total cycles |
|-----------------|-------------|:------------:|
| ALU reg, ALU imm, shift, MOV, LI, skip | S0 + S1 | **2** |
| LB/SB (ptr, zp, pg, sp+off) | S0 + S1 + S2 | **3** |
| Branch (not taken) | S0 + S1 | **2** |
| Branch (taken) | S0 + S1 + S2 (reload PC) | **3** |
| JMP (ptr) | S0 + S1 | **2** |
| PUSH | S0 + S1 + S2 (sp--, write) | **3** |
| POP | S0 + S1 + S2 (read, sp++) | **3** |
| JAL | S0 + S1 + S2 + S3 + S4 (push PCH, push PCL, load PC) | **5** |
| RET | S0 + S1 + S2 + S3 (pop PCL, pop PCH) | **4** |
| Interrupt entry | S2 + S3 + S4 + S0 (push PCH, push PCL, push flags, load vector) | **4** (+ current instr) |

---

## 4. Direct-Encoded Instruction Format

### 4.1 Opcode Byte (Byte 0) Bit Fields

```
Bit 7  6  5  4  3  2  1  0
    [  unit  ][ operation ][ reg/mode ]
     3 bits     3 bits       2 bits
```

| Bits [7:5] | Unit | Directly enables |
|:----------:|------|-----------------|
| 000 | ALU | ALU chip + flags write |
| 001 | Immediate | Immediate bus mux + register write |
| 010 | Load/Store | Memory address mux + mem read/write |
| 011 | Branch/Skip/Jump | PC load logic + flag check |
| 100 | Shift/Unary | Shift logic + register write |
| 101 | Pointer | Pointer increment logic |
| 111 | System | Flag set/clear, interrupt, halt |

**Bits [7:5] wire directly to a 74HC138** → one-hot unit enable. No decode logic needed.

**Bits [4:2]** wire directly to ALU op select, shift type, branch condition, or LI register select depending on unit.

**Bits [1:0]** wire directly to register mux select.

### 4.2 Operand Byte (Byte 1)

| For instruction type | Byte 1 meaning |
|---------------------|----------------|
| ALU register | bits [2:0] = source register |
| Immediate | 8-bit value |
| Load/Store (ptr) | bits [2:0] = register |
| Load/Store (addressed) | 8-bit offset/address |
| Branch | signed 8-bit offset |
| Skip | 0x00 (unused) |
| Jump | 0x00 (unused) |
| Shift/Unary | bits [2:0] = target register |
| System | trap number (for TRAP) or 0x00 |

---

## 5. Module Interfaces (Verilog)

### 5.1 Top-Level

```verilog
module rv8_cpu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        nmi_n,
    input  wire        irq_n,
    output wire [15:0] addr,
    inout  wire [7:0]  data,
    output wire        rd_n,
    output wire        wr_n,
    output wire        halt
);
```

### 5.2 ALU

```verilog
module rv8_alu (
    input  wire [7:0]  a,        // always a0
    input  wire [7:0]  b,        // register or immediate
    input  wire [2:0]  op,       // from opcode bits [4:2]
    input  wire        carry_in,
    output wire [7:0]  result,
    output wire        carry_out,
    output wire        zero,
    output wire        negative
);
```

### 5.3 Register File

```verilog
module rv8_regfile (
    input  wire        clk,
    input  wire        we,
    input  wire [2:0]  rd_sel,   // destination register
    input  wire [2:0]  rs_sel,   // source register (from operand byte)
    input  wire [7:0]  wr_data,
    output wire [7:0]  rd_data,  // source register value
    output wire [7:0]  a0,       // always available (ALU input A)
    output wire [7:0]  sp,
    output wire [7:0]  pl,
    output wire [7:0]  ph,
    output wire [7:0]  pg,
    input  wire [1:0]  const_sel // constant generator select
);
```

### 5.4 Program Counter

```verilog
module rv8_pc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        inc,       // PC += 1
    input  wire        load,      // PC = load_val
    input  wire        branch,    // PC = PC + offset
    input  wire [15:0] load_val,  // from {ph,pl} or vector
    input  wire [7:0]  offset,    // signed branch offset
    output wire [15:0] pc_out
);
```

### 5.5 Control Unit

```verilog
module rv8_control (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  opcode,    // IR byte 0
    input  wire [7:0]  operand,   // IR byte 1
    input  wire        flag_z,
    input  wire        flag_c,
    input  wire        flag_n,
    input  wire        flag_ie,
    input  wire        nmi_n,
    input  wire        irq_n,
    // Control outputs
    output wire        reg_we,
    output wire        mem_rd,
    output wire        mem_wr,
    output wire [2:0]  alu_op,
    output wire [2:0]  addr_src,  // PC/ptr/stack/zp/pg/vector
    output wire        pc_inc,
    output wire        pc_load,
    output wire        pc_branch,
    output wire        flags_we,
    output wire        ptr_inc,
    output wire        sp_inc,
    output wire        sp_dec,
    output wire        skip_next,
    output wire        halt_out,
    output wire [2:0]  state      // current FSM state (for debug LEDs)
);
```

---

## 6. Timing Diagram

### 6.1 Simple ALU Instruction (2 cycles)

```
CLK:     ───┐  ┌───┐  ┌───┐  ┌───
            └──┘   └──┘   └──┘

State:   │  S0     │  S1     │  S0     │
         │         │         │         │

ADDR:    │  PC     │  PC+1   │  PC+2   │
         │         │         │         │

DATA:    │  opcode │ operand │  next_op│
         │  (in)   │  (in)   │  (in)   │

Action:  │ Latch   │ Latch   │ Latch   │
         │ opcode  │ operand │ next op │
         │ into IR │ +EXEC   │         │
         │         │ prev    │         │
         │         │ instr   │         │

PC:      │  +1     │  +1     │  +1     │
```

### 6.2 Memory Load Instruction (3 cycles)

```
CLK:     ───┐  ┌───┐  ┌───┐  ┌───┐  ┌───
            └──┘   └──┘   └──┘   └──┘

State:   │  S0     │  S1     │  S2     │  S0     │

ADDR:    │  PC     │  PC+1   │ {pg,imm}│  PC+2   │
         │         │         │ (data)  │         │

DATA:    │  opcode │ operand │ mem_data│  next_op│
         │         │         │ (read)  │         │

Action:  │ Fetch   │ Fetch   │ Read    │ Fetch   │
         │ opcode  │ operand │ memory  │ next    │
         │         │ +decode │ →a0     │ opcode  │
```

### 6.3 Branch Taken (3 cycles)

```
CLK:     ───┐  ┌───┐  ┌───┐  ┌───┐  ┌───
            └──┘   └──┘   └──┘   └──┘

State:   │  S0     │  S1     │  S2     │  S0     │

ADDR:    │  PC     │  PC+1   │  --     │ new_PC  │

Action:  │ Fetch   │ Fetch   │ Compute │ Fetch   │
         │ opcode  │ offset  │ PC+off  │ from    │
         │         │ +check  │ load PC │ new PC  │
         │         │ flags   │         │         │
```

---

## 7. Chip-to-Signal Mapping (20 CPU chips)

| Chip | Part | Signals driven |
|------|------|---------------|
| U1 | 74HC161 | PC[3:0], carry out to U2 |
| U2 | 74HC161 | PC[7:4], carry out to U3 |
| U3 | 74HC161 | PC[11:8], carry out to U4 |
| U4 | 74HC161 | PC[15:12] + FSM state[1:0] (shared) |
| U5 | 74HC574 | IR byte 0 (opcode latch) |
| U6 | 74HC574 | IR byte 1 (operand latch) / prefetch |
| U7 | 74HC574 | Registers: a0 |
| U8 | 74HC574 | Registers: t0 + sp (nibble-shared or separate) |
| U9 | 74HC574 | Registers: pl + ph |
| U10 | 74HC574 | Registers: pg + constant gen output |
| U11 | 74HC283 | ALU adder low nibble |
| U12 | 74HC283 | ALU adder high nibble |
| U13 | 74HC86 | ALU XOR (for subtract invert + XOR op) |
| U14 | 74HC08 | ALU AND + flag logic |
| U15 | 74HC32 | ALU OR + control signal combining |
| U16 | 74HC157 | Address mux low byte (4× 2:1) |
| U17 | 74HC157 | Address mux high byte (4× 2:1) |
| U18 | 74HC138 | Unit decode (opcode[7:5] → unit enable) |
| U19 | 74HC245 | Data bus buffer (bidirectional) |
| U20 | 74HC74 | Flags (Z, C, N, IE) + skip FF + NMI edge detect |

---

## 8. Bus Protocol

### 8.1 Memory Read

```
         ┌─────────────────────────────┐
ADDR:    │  Valid address              │
         └─────────────────────────────┘
              ┌────────────────────────┐
/RD:     ─────┘                        └─────
                        ┌──────────────┐
DATA:    ───────────────│  Valid data   │─────  (driven by memory)
                        └──────────────┘
                                    ▲
                              CPU latches here (rising CLK)
```

### 8.2 Memory Write

```
         ┌─────────────────────────────┐
ADDR:    │  Valid address              │
         └─────────────────────────────┘
         ┌─────────────────────────────┐
DATA:    │  Valid data (from CPU)      │
         └─────────────────────────────┘
                   ┌───────────────┐
/WR:     ──────────┘               └──────────
                                ▲
                          Memory latches here (rising /WR)
```

---

## 9. Interrupt Sequence

```
Normal execution:  ... S0 S1 S0 S1 S0 S1 ...
                                    ▲
                              IRQ detected (between instructions)
                                    │
Interrupt entry:              S2    S3    S4    S0
                              push  push  push  fetch
                              PCH   PCL   flags from
                                                vector

Vector fetch: addr = 0xFFFA (NMI) or 0xFFFE (IRQ) or 0xFFF6 (TRAP)
PC loaded from vector, IE cleared, execution continues from ISR.
```

---

## 10. Conditional Skip Implementation

```
SKIPZ instruction detected:
  → Set skip_flag flip-flop if Z==1
  → Next instruction fetches normally (S0, S1)
  → But reg_we, mem_wr, pc_load, sp_inc/dec are all AND-gated with !skip_flag
  → Instruction executes as NOP (no side effects)
  → skip_flag auto-clears after one instruction
```

Cost: 1 flip-flop (in U20) + 1 AND gate per write-enable signal (absorbed into existing logic).

---

## 11. Constant Generator Implementation

```
Register select = 000 (x0/c0):
  → Output mux selects from:
    operand[3:2] == 00 → 0x00
    operand[3:2] == 01 → 0x01
    operand[3:2] == 10 → 0xFF
    operand[3:2] == 11 → 0x80

Hardware: 1× 74HC157 (quad 2:1 mux) configured as 4-input selector
  → Directly wired to operand byte bits [3:2]
  → Output feeds into ALU input B when register select = 000
```

---

## 12. Design Verification Checklist

Before proceeding to Verilog (Phase 4), verify:

- [ ] All 68 instructions have unambiguous encoding (no opcode conflicts)
- [ ] Fetch/execute overlap timing is valid (no bus conflicts)
- [ ] Address mux covers all 7 sources without conflict
- [ ] Interrupt can insert between any two instructions
- [ ] Stack overflow detection triggers NMI correctly
- [ ] Skip flag clears after exactly 1 instruction
- [ ] Constant generator doesn't conflict with normal register reads
- [ ] Branch offset calculation is correct (PC already advanced by 2)
- [ ] JAL pushes correct return address (PC after JAL instruction)
- [ ] All control signals have defined values in every state

---

*Next Phase: Verilog Implementation (Phase 4)*
