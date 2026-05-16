# RV8-GR — Understand by Module

**21 chips. No microcode. Control byte = control wires.**

---

## 4 Modules

```
┌──────────────────────────────────────────────────┐
│  Module 1: AC + ALU (U1, U3-U6, U11-U12)        │
│  Module 2: PC + Address (U7, U13-U18, U21)       │
│  Module 3: Memory Interface (U9, U10, U19)        │
│  Module 4: Instruction + State (U2, U8, U14, U20)│
└──────────────────────────────────────────────────┘
```

## Module 1: AC + ALU (the calculator)

**Chips**: U1 (574 AC) + U3-U4 (283 adder) + U5-U6 (86 XOR) + U11-U12 (157 mux)

AC is the ONLY real register. Its Q outputs are hardwired to adder A inputs (always computing). The mux (U11-U12) selects what goes into AC: adder result, XOR result, or IBUS data.

## Module 2: PC + Address (the navigator)

**Chips**: U7+U13 (157 addr mux) + U14 (161 state counter) + U15-U18 (161 PC) + U21 (32 OR gates)

PC auto-increments during fetch. Address mux selects PC (fetch) or operand (data access). State counter cycles 0→1→2→0 (3 states per instruction).

## Module 3: Memory Interface (the bridge)

**Chips**: U9 (541 AC buffer) + U10 (245 bus bridge) + U19 (541 PC buffer)

U10 bridges IBUS to RAM data bus. U9 puts AC value on IBUS (for store). U19 puts PC value on IBUS (for JAL).

## Module 4: Instruction + State (the controller)

**Chips**: U2 (574 IR_HIGH) + U8 (574 IR_LOW) + U14 (161 state) + U20 (74 flags)

IR_HIGH holds the control byte — its Q outputs ARE the control signals. No decode needed! U8 holds the operand. U14 counts states. U20 remembers if last result was zero (for branches).

---

## How `ADDI a0, a0, 5` executes:

```
State 0: PC→ROM→$10 (control byte)→U2 latches. PC++.
State 1: PC→ROM→$05 (operand)→U8 latches. PC++.
State 2: U2 says: AC_WR=1, SOURCE=imm, SUB=0
          IBUS = $05 (from U8, immediate)
          ALU: AC($10) + IBUS($05) = $15
          Mux selects adder result → AC latches $15. Done!
```

**3 clocks. No microcode. No lookup. Just wires.**
