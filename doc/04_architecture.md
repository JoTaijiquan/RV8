# RV8 — Architecture (matches verified Verilog)

**Source of truth**: `rtl/rv8_cpu.v` (69 tests pass)

---

## 1. Block Diagram

```
                    ┌──────────────────────────────────────┐
                    │           ADDRESS BUS (16-bit)        │
                    └──┬──────┬──────┬──────┬──────┬───────┘
                       │      │      │      │      │
                    ┌──▼──┐┌──▼──┐┌──▼──┐┌──▼──┐┌──▼──┐
                    │ PC  ││ PTR ││STACK││ ZP  ││VECT │
                    │16bit││ph:pl││30:sp││00:im││FF:im│
                    └──┬──┘└──┬──┘└──┬──┘└──┬──┘└──┬──┘
                       └──────┴──────┴──────┴──────┘
                                     │
                    ┌────────────────▼─────────────────────┐
                    │           DATA BUS (8-bit)            │
                    └──┬──────┬──────┬──────┬──────────────┘
                       │      │      │      │
                    ┌──▼──┐┌──▼──┐┌──▼──┐┌──▼──┐
                    │ IR  ││REGS ││ ALU ││MEM  │
                    │op+op││a0,t0││8-bit││R/W  │
                    │     ││sp,pg││     ││     │
                    └─────┘└─────┘└─────┘└─────┘
                                     │
                    ┌────────────────▼─────────────────────┐
                    │         CONTROL (state machine)       │
                    │   17 states, opcode-range decode      │
                    └──────────────────────────────────────┘
```

---

## 2. State Machine (17 states)

```
BOOT:  B0 → B1 → B2 → F1 (read reset vector, start fetch)

NORMAL: F1 → EX → F1  (2-cycle: fetch opcode, fetch operand + execute)
                  ↘ M1 → F1  (3-cycle: + memory read)
                  ↘ M2 → M3 → F1  (4-cycle: + memory write)
                  ↘ S10 → S11 → F1  (JAL: push PCH, push PCL, jump)
                  ↘ S10 → S16 → S11 → S15 → S13 → F1  (TRAP: push+flags+vector)
                  ↘ S12 → S13 → F1  (RET: pop PCL, pop PCH)
                  ↘ S14 → S12 → S13 → F1  (RTI: pop flags, pop PC)

HALT:  HLT (wake on IRQ/NMI → S15 → S13 → F1)
```

| State | # | Action |
|-------|:-:|--------|
| B0 | 0 | addr=0xFFFC, read |
| B1 | 1 | latch PC_lo, addr=0xFFFD, read |
| B2 | 2 | latch PC_hi, addr=PC, read |
| F1 | 3 | latch opcode, addr=PC+1, read |
| EX | 4 | latch operand, execute instruction, PC+=2 |
| M1 | 5 | latch memory read → a0 |
| M2 | 6 | drive data_out, assert write |
| HLT | 7 | halted (wake on interrupt) |
| M3 | 9 | write done, next fetch |
| JAL_S2 | 10 | push PCL |
| JAL_S3 | 11 | jump to {ph,pl} or read vector |
| RET_S2 | 12 | latch PCL, read PCH |
| RET_S3 | 13 | latch PCH, fetch from new PC |
| RTI_S1 | 14 | latch flags, pop PCL |
| INT_S1 | 15 | latch vector low, read vector high |
| TRAP_S3 | 16 | push flags byte |

---

## 3. Datapath

### Internal paths (no bus conflict):
```
Registers (a0,t0,sp,pg) → ALU input A (a0 always)
Operand byte / register → ALU input B
ALU result → register write (a0 or data_out)
```

### External bus (memory access):
```
Address mux → address bus → memory
Memory → data bus → IR latch / register load
Register → data bus → memory (for stores)
```

**Key**: ALU operates on internal wires. External bus only used for memory read/write.

---

## 4. Chip Mapping (23 CPU chips)

| # | Part | Function | Pins used |
|---|------|----------|-----------|
| 1-4 | 74HC161 ×4 | PC (16-bit counter with parallel load) | All |
| 5-6 | 74HC574 ×2 | IR opcode + operand (clock-gated) | All |
| 7 | 74HC574 | a0 (accumulator) | All |
| 8 | 74HC574 | t0 (temporary) | All |
| 9 | 74HC574 | sp (stack pointer, 8-bit) | All |
| 10 | 74HC574 | pg (page register) | All |
| 11 | 74HC161 | pl (pointer low, count for ptr+) | All |
| 12 | 74HC161 | ph (pointer high, carry from pl) | All |
| 13-14 | 74HC283 ×2 | ALU 8-bit adder | All |
| 15 | 74HC86 | ALU XOR (SUB invert + XOR op) | All |
| 16-17 | 74HC157 ×2 | Address mux low + high byte | All |
| 18 | 74HC138 | Address decode + unit select | All |
| 19 | 74HC245 | Data bus buffer (bidirectional) | All |
| 20-21 | 74HC74 ×2 | Flags (Z,C,N,IE) + state + skip + NMI | All |
| 22-23 | 74HC08+32 | AND/OR control logic | Partial |

---

## 5. Timing

### 2-cycle instruction (ALU, LI, shift, MOV, branch-not-taken, skip, NOP):
```
CLK:  ─┐ ┌─┐ ┌─
       └─┘ └─┘
State: F1  EX  F1
Bus:   [op][opr][next_op]
```

### 3-cycle instruction (LB, POP, branch-taken):
```
State: F1  EX  M1  F1
Bus:   [op][opr][data][next_op]
```

### 4-cycle instruction (SB, PUSH):
```
State: F1  EX  M2  M3  F1
Bus:   [op][opr][wr][--][next_op]
```

### 5-cycle (JAL):
```
State: F1  EX  S10  S11  F1
Bus:   [op][opr][push_h][push_l][target_op]
```

---

## 6. Address Sources

| Sel | High byte | Low byte | Used by |
|:---:|-----------|----------|---------|
| 0 | PC[15:8] | PC[7:0] | Fetch |
| 1 | ph | pl | LB/SB (ptr) |
| 2 | 0x30 | sp | PUSH/POP/JAL/RET |
| 3 | 0x00 | imm8 | Zero-page |
| 4 | pg | imm8 | Page-relative |
| 5 | 0x30 | sp+imm8 | Stack-relative |
| 6 | 0xFF | vector_lo | Interrupt vectors |

---

## 7. Key Design Decisions (verified correct)

| Decision | Rationale | Verified by |
|----------|-----------|-------------|
| Opcode-range decode (not bit-field) | ISA opcodes aren't bit-aligned to units | All 69 tests |
| Inline ALU computation in EX state | Combinational ALU module can't feedback in same clk | ADDI/SUBI tests |
| Non-overlapping const_sel bits [4:3] | Avoids conflict with reg select bits [2:0] | Const gen tests |
| 5-bit state register | 17 states > 16 (4-bit limit) | TRAP/RTI tests |
| SBC uses `{8'd0, ~fc}` for borrow | Prevents sign-extension of 1-bit `~fc` | SBC test |
| TRAP sets ptr before push sequence | Vector read happens after push completes | TRAP test |
| NMI/IRQ read vector via states 15→13 | Reuses RET_S3 for PC load | IRQ/NMI tests |
| Skip flag checked at EX entry | Suppresses entire instruction | SKIP tests |

---

## 8. Performance

| Metric | Value |
|--------|-------|
| Clock | 3.5 MHz (breadboard) |
| Avg cycles/instruction | ~2.5 |
| Instructions/sec | ~1.4M |
| BASIC lines/sec | ~400 |

---

## 9. Gate Count (from chip list)

| Component | Gates |
|-----------|:-----:|
| 6× 74HC161 (PC + ptr) | 150 |
| 6× 74HC574 (IR + regs) | 180 |
| 2× 74HC283 (ALU adder) | 100 |
| 1× 74HC86 (XOR) | 30 |
| 2× 74HC157 (addr mux) | 80 |
| 1× 74HC138 (decode) | 30 |
| 1× 74HC245 (bus buf) | 40 |
| 2× 74HC74 (flags+state) | 50 |
| 2× 74HC08/32 (logic) | 70 |
| **Total** | **~730** |
