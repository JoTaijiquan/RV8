# Lab 4: Instruction Register

## Objective
Latch the opcode (byte 0) and operand (byte 1) of each 2-byte instruction into separate registers.

## Components
| Part | Qty | Description |
|------|:---:|-------------|
| 74HC574 | 2 | Octal D flip-flop (edge-triggered) |
| 74HC74 | 1 | Dual D flip-flop (state toggle) |
| LED + 330Ω | 8 | Opcode display (optional, reuse data bus LEDs) |

## Concept

RV8 instructions are 2 bytes. The CPU alternates between two states:
- **S0**: fetch opcode → latch into IR0 (U5)
- **S1**: fetch operand → latch into IR1 (U6)

A single flip-flop toggles between S0 and S1 each clock cycle.

## Schematic

```
74HC74 (one flip-flop used as toggle):
  D ← /Q (feeds back inverted output)
  CLK ← CLK
  /CLR ← /RST
  Q = state (0=S0, 1=S1)

U5 (IR opcode, 74HC574):
  D[7:0] ← data bus
  CLK ← CLK AND (state==0)    [= CLK when Q=LOW]
  /OE ← GND

U6 (IR operand, 74HC574):
  D[7:0] ← data bus
  CLK ← CLK AND (state==1)    [= CLK when Q=HIGH]
  /OE ← GND

Clock gating (use AND gate or NAND):
  ir0_clk = CLK AND /Q    (active during S0)
  ir1_clk = CLK AND Q     (active during S1)
  (Can use 74HC08 AND gate, or wire with a NAND trick)
```

## Procedure

1. Insert 74HC74. Use one flip-flop as toggle: wire /Q back to D.
2. Connect CLK to 74HC74 CLK. Connect /RST to /CLR.
3. Q output = state signal. /Q = complement.
4. Insert U5 (74HC574). D inputs from data bus. CLK = (CLK AND /Q).
   - For clock gating: use one gate from a 74HC08 (AND), or for this test, manually wire.
   - Simple alternative: connect U5.CLK to /Q (latches on falling edge of state).
5. Insert U6 (74HC574). D inputs from data bus. CLK = (CLK AND Q).
   - Or connect U6.CLK to Q.
6. Tie both /OE pins to GND.
7. Add LEDs to U5 outputs (opcode) and U6 outputs (operand).

## Pre-Lab
Program ROM with known instruction pairs:
```
$0000: $11 $05    ; LI a0, 5    (opcode=$11, operand=$05)
$0002: $16 $03    ; ADDI 3      (opcode=$16, operand=$03)
$0004: $FF $00    ; HLT         (opcode=$FF, operand=$00)
```

## Test Procedure

| Test | Action | Expected Result |
|:----:|--------|-----------------|
| 1 | RESET | State=S0, both IR cleared |
| 2 | Step 1× | U5 latches $11 (opcode), state→S1 |
| 3 | Step 1× | U6 latches $05 (operand), state→S0 |
| 4 | Step 1× | U5 latches $16 (next opcode), state→S1 |
| 5 | Step 1× | U6 latches $03 (next operand), state→S0 |
| 6 | Step 1× | U5 latches $FF (HLT opcode) |
| 7 | RESET | U5 and U6 return to first instruction |

## Checkoff

- [ ] U5 latches only on S0 (even cycles)
- [ ] U6 latches only on S1 (odd cycles)
- [ ] Opcode and operand match ROM contents
- [ ] State toggles cleanly (no double-clocking)
- [ ] RESET clears state to S0

## Notes
- In the final CPU, the state machine is more complex (S0→S1→S2→...) for multi-cycle instructions. This 2-state version is sufficient for fetch testing.
- The 74HC08 AND gate for clock gating will be part of U22 in the final build.
- U5 outputs (opcode bits) will later drive the control unit decode logic.
