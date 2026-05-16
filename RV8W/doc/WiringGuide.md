# RV8-W CPU — WiringGuide (Bus-Centric)

```
// ═══════════════════════════════════════════════════════════════
// RV8-W CPU — WiringGuide (Bus-Centric)
// 25 logic chips + ROM + RAM = 27 packages
//
// NO MICROCODE. Instruction control byte directly drives hardware.
// 2-cycle fetch: cycle 1 = control byte → IR_HIGH, cycle 2 = operand + execute
//
// THREE BUSES:
//   RV8-Bus (external, 40-pin): A[15:0] + D[7:0] → RAM, peripherals
//   IBUS (internal, 8-bit): connects registers, ALU B input, bus buffer, AC buffer
//   ALU_A (internal, hardwired): AC Q outputs → adder A inputs (always, no mux)
//
// U22 (74HC245) bridges IBUS ↔ RV8-Bus D[7:0]
// U25 (74HC541) bridges AC Q → IBUS (for store/move operations)
// ═══════════════════════════════════════════════════════════════

Project: RV8-W,

// ═══════════════════════════════════════════════════════════════
// RV8-Bus (EXTERNAL) — 40-pin connector to RAM, peripherals
// ═══════════════════════════════════════════════════════════════

RV8_Bus:{
    // --- Address (from PC or register via U24 mux) ---
    A0:  U24.Y1,   // mux: PC0 or REG_A0
    A1:  U24.Y2,   // mux: PC1 or REG_A1
    A2:  U24.Y3,   // mux: PC2 or REG_A2
    A3:  U24.Y4,   // mux: PC3 or REG_A3
    A4:  U16.Q0 or REG_A4,  // PC[7:4] or register high nibble
    A5:  U16.Q1 or REG_A5,
    A6:  U16.Q2 or REG_A6,
    A7:  U16.Q3 or REG_A7,
    A8:  U21.Y1,   // PC high via buffer (ROM only) or register
    A9:  U21.Y2,
    A10: U21.Y3,
    A11: U21.Y4,
    A12: U21.Y5,
    A13: U21.Y6,
    A14: U21.Y7,
    A15: U21.Y8,
    // PC (U15-U18) drives during fetch (MEM_MODE=0)
    // Register value drives during memory access (MEM_MODE=1, via U24)

    // --- Data (bridged to IBUS via U22) ---
    D0: U22.A1,  D1: U22.A2,  D2: U22.A3,  D3: U22.A4,
    D4: U22.A5,  D5: U22.A6,  D6: U22.A7,  D7: U22.A8,

    // --- Control ---
    "/RD": from_control (MEM_EN AND NOT MEM_RW),
    "/WR": from_control (MEM_EN AND MEM_RW),
    CLK:  crystal_oscillator,
    "/RST": reset_circuit,
    "/NMI": pull-up_10K (reserved),
    "/IRQ": pull-up_10K (reserved),
    HALT: (reserved),
    SYNC: STATE (0=fetch, 1=execute),

    // --- 40-pin pinout (same as RV8) ---
    pin_1:A0, pin_2:A1, pin_3:A2, pin_4:A3,
    pin_5:A4, pin_6:A5, pin_7:A6, pin_8:A7,
    pin_9:A8, pin_10:A9, pin_11:A10, pin_12:A11,
    pin_13:A12, pin_14:A13, pin_15:A14, pin_16:A15,
    pin_17:D0, pin_18:D1, pin_19:D2, pin_20:D3,
    pin_21:D4, pin_22:D5, pin_23:D6, pin_24:D7,
    pin_25:"/RD", pin_26:"/WR", pin_27:CLK, pin_28:"/RST",
    pin_29:"/NMI", pin_30:"/IRQ", pin_31:HALT, pin_32:SYNC,
    pin_33:nc, pin_34:nc, pin_35:nc, pin_36:nc,
    pin_37:nc, pin_38:nc, pin_39:VCC, pin_40:GND
},

// ═══════════════════════════════════════════════════════════════
// IBUS (INTERNAL) — 8-bit shared bus inside the CPU
// Only ONE chip drives IBUS at a time (control byte ensures)
// ═══════════════════════════════════════════════════════════════

IBUS:{
    width: 8,
    drivers: [
        "U2-U8 (registers r1-r7, selected by U19 /OE decode)",
        "U10 (IR_LOW/operand, when IMM_MODE=1 AND STATE=1)",
        "U22 (bus buffer, when reading RAM → IBUS)",
        "U25 (AC buffer, when AC_TO_BUS=1)"
    ],
    consumers: [
        "U2-U8 (register D inputs, latched by U20 CLK decode)",
        "U13-U14 (XOR gates → ALU B input)",
        "U22 (bus buffer, when writing IBUS → RAM)"
    ],
    rule: "Control byte ensures only ONE driver active per cycle 2"
},

// ═══════════════════════════════════════════════════════════════
// ALU_A (INTERNAL, HARDWIRED) — AC Q always drives adder A inputs
// NOT a bus — dedicated point-to-point traces
// ═══════════════════════════════════════════════════════════════

ALU_A:{
    width: 8,
    type: "hardwired (not tri-state, not shared)",
    driver: "U1 Q[7:0] (AC, /OE=GND, always enabled)",
    consumers: [
        "U11 A1-A4 (adder low nibble, bits 3:0)",
        "U12 A1-A4 (adder high nibble, bits 7:4)",
        "U25 A1-A8 (AC→IBUS buffer inputs)"
    ],
    note: "AC outputs ALWAYS connected. No mux, no control needed."
},

// ═══════════════════════════════════════════════════════════════
// CHIPS ON IBUS (internal bus)
// ═══════════════════════════════════════════════════════════════

Part:{

    // --- ACCUMULATOR (on ALU_A, NOT on IBUS directly) ---
    U1:{type:74HC574, bus:ALU_A, function:"AC (accumulator, hardwired to ALU A)",
        1:GND, 11:AC_CLK, "2-9":"ALU_result[7:0]", "12-19":"→ALU_A + U25_inputs", 10:GND, 20:VCC},
    // /OE(1)=GND: ALWAYS drives (Q→adder A inputs + U25 buffer inputs)
    // CLK(11)=AC_CLK: gated CLK, fires when AC_WR=1 AND STATE=1 AND CLK↑
    // D(2-9) from ALU result (adder Σ outputs, direct wire)
    // Q(12-19) hardwired to U11.A, U12.A, U25.A (always)

    // --- REGISTERS (on IBUS) ---
    U2:{type:74HC574, bus:IBUS, function:"r1 (a1)",
        1:U19.Y1, 11:U20.Y1, "2-9":IBUS, "12-19":IBUS, 10:GND, 20:VCC},
    U3:{type:74HC574, bus:IBUS, function:"r2 (t0)",
        1:U19.Y2, 11:U20.Y2, "2-9":IBUS, "12-19":IBUS, 10:GND, 20:VCC},
    U4:{type:74HC574, bus:IBUS, function:"r3 (t1)",
        1:U19.Y3, 11:U20.Y3, "2-9":IBUS, "12-19":IBUS, 10:GND, 20:VCC},
    U5:{type:74HC574, bus:IBUS, function:"r4 (s0)",
        1:U19.Y4, 11:U20.Y4, "2-9":IBUS, "12-19":IBUS, 10:GND, 20:VCC},
    U6:{type:74HC574, bus:IBUS, function:"r5 (s1)",
        1:U19.Y5, 11:U20.Y5, "2-9":IBUS, "12-19":IBUS, 10:GND, 20:VCC},
    U7:{type:74HC574, bus:IBUS, function:"r6 (s2)",
        1:U19.Y6, 11:U20.Y6, "2-9":IBUS, "12-19":IBUS, 10:GND, 20:VCC},
    U8:{type:74HC574, bus:IBUS, function:"r7 (ra/sp)",
        1:U19.Y7, 11:U20.Y7, "2-9":IBUS, "12-19":IBUS, 10:GND, 20:VCC},
    // /OE(1) from U19 (read decode) — selects who drives IBUS
    // CLK(11) from U20 (write decode) — selects who latches from IBUS
    // D(2-9) from IBUS (data to latch)
    // Q(12-19) to IBUS (when /OE=LOW)

    // --- IR (latches from ROM data bus) ---
    U9:{type:74HC574, bus:control, function:"IR_HIGH (control byte — outputs DIRECTLY drive hardware)",
        1:GND, 11:IR_CLK, "2-9":"ROM_D[7:0]", "12-19":"→hardware_control", 10:GND, 20:VCC},
    // /OE(1)=GND: always enabled — outputs are the control signals!
    // CLK(11)=IR_CLK: fires on CLK↑ when STATE=0 (cycle 1)
    // D(2-9) from ROM data bus (SST39SF010A D[7:0])
    // Q outputs:
    //   Q7=CLASS, Q6=ALU_OP2, Q5=ALU_OP1, Q4=ALU_OP0,
    //   Q3=IMM_MODE, Q2=AC_WR, Q1=REG_WR, Q0=AC_TO_BUS

    U10:{type:74HC574, bus:IBUS, function:"IR_LOW (operand byte, drives IBUS for immediates)",
        1:IMM_OE, 11:OP_CLK, "2-9":"ROM_D[7:0]", "12-19":IBUS, 10:GND, 20:VCC},
    // /OE(1)=IMM_OE: LOW when IMM_MODE=1 AND STATE=1 → drives IBUS
    // CLK(11)=OP_CLK: fires on CLK↑ when STATE=1 (cycle 2)
    // D(2-9) from ROM data bus
    // Q(12-19) to IBUS (immediate value or register select fields)

    // --- ALU (internal, feeds from ALU_A and IBUS via XOR) ---
    U11:{type:74HC283, bus:internal, function:"ALU adder low nibble (bits 3:0)",
        "A1-A4":"ACQ[3:0] (from U1, hardwired)", "B1-B4":"XOR_out[3:0] (from U13)",
        C0:SUB, "S1-S4":"→U1.D[3:0] (ALU result)", C4:"→U12.C0"},
    U12:{type:74HC283, bus:internal, function:"ALU adder high nibble (bits 7:4)",
        "A1-A4":"ACQ[7:4] (from U1, hardwired)", "B1-B4":"XOR_out[7:4] (from U14)",
        C0:"U11.C4", "S1-S4":"→U1.D[7:4] (ALU result)", C4:"CARRY→U23.D2"},
    U13:{type:74HC86, bus:internal, function:"XOR low (SUB invert bits 0-3)",
        "inputs":"IBUS[3:0] XOR SUB", "outputs":"→U11.B[3:0]"},
    U14:{type:74HC86, bus:internal, function:"XOR high (SUB invert bits 4-7)",
        "inputs":"IBUS[7:4] XOR SUB", "outputs":"→U12.B[7:4]"},
    // SUB = ALU_OP0 (from U9 Q4). When SUB=1: inverts B + Cin=1 = two's complement

    // --- AC→IBUS BUFFER (bridges AC onto IBUS for store/move) ---
    U25:{type:74HC541, bus:IBUS, function:"AC→IBUS buffer (for MV rd,a0 and SB)",
        1:"/AC_TO_BUS", 19:GND,
        "2-9":"ACQ[7:0] (from U1 Q, hardwired)", "11-18":"IBUS[7:0]",
        10:GND, 20:VCC},
    // /OE1(1)=inverted AC_TO_BUS: LOW when AC_TO_BUS=1 → AC value on IBUS
    // /OE2(19)=GND: always enabled (controlled by /OE1 only)
    // A(2-9) from U1 Q outputs (same traces as ALU_A)
    // Y(11-18) to IBUS (when enabled)

    // --- PC (drives ROM address, always counting) ---
    U15:{type:74HC161, bus:ROM_addr, function:"PC bits 3:0",
        1:"/RESET", 2:CLK, "3-6":"JMP[3:0]", 7:VCC, 9:"/PC_LOAD", 10:VCC,
        "11-14":"PC[3:0]→ROM_A[3:0]", 15:"TC→U16.ENT", 8:GND, 16:VCC},
    U16:{type:74HC161, bus:ROM_addr, function:"PC bits 7:4",
        1:"/RESET", 2:CLK, "3-6":"JMP[7:4]", 7:VCC, 9:"/PC_LOAD", 10:"U15.TC",
        "11-14":"PC[7:4]→ROM_A[7:4]", 15:"TC→U17.ENT", 8:GND, 16:VCC},
    U17:{type:74HC161, bus:ROM_addr, function:"PC bits 11:8",
        1:"/RESET", 2:CLK, "3-6":"JMP[11:8]", 7:VCC, 9:"/PC_LOAD", 10:"U16.TC",
        "11-14":"PC[11:8]→U21.A[3:0]", 15:"TC→U18.ENT", 8:GND, 16:VCC},
    U18:{type:74HC161, bus:ROM_addr, function:"PC bits 15:12",
        1:"/RESET", 2:CLK, "3-6":"JMP[15:12]", 7:VCC, 9:"/PC_LOAD", 10:"U17.TC",
        "11-14":"PC[15:12]→U21.A[7:4]", 15:"unused", 8:GND, 16:VCC},
    // All PCs: ENP=VCC (always enabled), /CLR=/RESET
    // /LOAD: LOW to load jump target, HIGH for normal count
    // PC increments every clock (both cycles) — 2 bytes per instruction

    // --- PC HIGH BUFFER (buffers PC[15:8] to ROM address) ---
    U21:{type:74HC541, bus:ROM_addr, function:"PC high buffer (PC[15:8]→ROM A[15:8])",
        1:GND, 19:GND,
        "2-9":"PC[15:8] (from U17+U18)", "11-18":"ROM_A[15:8]",
        10:GND, 20:VCC},
    // /OE1=GND, /OE2=GND: always enabled (ROM always addressed by PC)

    // --- ADDRESS MUX (selects PC or register for RAM address) ---
    U24:{type:74HC157, bus:RV8_Bus_addr, function:"Addr mux low (PC vs register for RAM)",
        1:GND, 2:MEM_MODE,
        "A inputs":"PC[3:0]", "B inputs":"REG[3:0]",
        "Y outputs":"RAM_A[3:0]",
        8:GND, 16:VCC},
    // /G(1)=GND: always enabled
    // SEL(2)=MEM_MODE: 0=PC (normal), 1=register (memory access)

    // --- BUS BRIDGE (connects IBUS ↔ RV8-Bus D[7:0]) ---
    U22:{type:74HC245, bus:both, function:"Bridge: IBUS ↔ RAM data",
        1:MEM_RW, 19:"/MEM_EN",
        "2-9":"RAM_D[7:0] (A side, RV8-Bus)", "11-18":"IBUS[7:0] (B side)",
        10:GND, 20:VCC},
    // DIR(1): 0=A→B (RAM→IBUS for LB), 1=B→A (IBUS→RAM for SB)
    // /OE(19): LOW only during memory access cycles

    // --- CONTROL (generates timing and decode signals) ---
    U19:{type:74HC138, bus:control, function:"Register READ select (who drives IBUS)",
        "A,B,C":"RS[2:0] from operand bits 7:5", G1:STATE, "/G2A":IMM_MODE,
        "/G2B":GND,
        "Y0":"→nowhere (r0 not implemented)",
        "Y1-Y7":"→U2-U8 /OE pins"},
    // Enabled only when STATE=1 AND IMM_MODE=0
    // RS field selects which register drives IBUS

    U20:{type:74HC138, bus:control, function:"Register WRITE select (who latches from IBUS)",
        "A,B,C":"RD[2:0] from operand bits 4:2", G1:STATE, "/G2A":"/REG_WR",
        "/G2B":GND,
        "Y0":"→nowhere (r0 not writable)",
        "Y1-Y7":"→U2-U8 CLK pins"},
    // Enabled only when STATE=1 AND REG_WR=1
    // RD field selects which register latches from IBUS

    U23:{type:74HC74, bus:control, function:"State toggle (FF1) + Zero flag (FF2)",
        "FF1":"D=/Q1 (toggle), CLK=CLK, Q=STATE, /CLR=/RESET",
        "FF2":"D=ALU_ZERO (NOR of result), CLK=AC_CLK, Q=ZERO_FLAG"},
    // FF1: toggles every clock → STATE alternates 0/1
    // FF2: latches zero detect when AC latches result
    // Carry flag: U12.Cout (directly available, no latch needed for combinational branch)

    // --- MEMORY (on RV8-Bus) ---
    ROM:{type:SST39SF010A, bus:ROM_addr, function:"PROGRAM ROM (128KB Flash, NOT microcode!)",
        "A[16:0]":"from PC (U15-U18 via U21)", "D[7:0]":"ROM data → U9.D + U10.D",
        "/CE":GND, "/OE":GND, "/WE":VCC},
    // Always selected, always output enabled
    // Addressed ONLY by PC — every clock reads next byte
    // Cycle 1: outputs control byte, Cycle 2: outputs operand byte

    RAM:{type:62256, bus:RV8_Bus, function:"Data RAM (32KB)",
        "A[14:0]":"from U24 mux + register high", "D[7:0]":"↔ U22 (bus buffer)",
        "/CE":"/MEM_EN", "/OE":"MEM_RW_n", "/WE":"/MEM_WR"},
    // Only accessed during memory instructions (LB/SB)
    // Address from register (via U24 mux when MEM_MODE=1)

    // --- SUPPORT ---
    OSC:{type:"Crystal 3.5MHz", output:CLK},
    R1:{type:"10K", 1:VCC, 2:"/RST"},
    SW:{type:"Pushbutton", 1:"/RST", 2:GND},
    C1:{type:"100nF", 1:"/RST", 2:GND}
}

// ═══════════════════════════════════════════════════════════════
// CONTROL BYTE (IR_HIGH Q outputs — directly drive hardware)
// No microcode! No step counter! No sequencer!
// ═══════════════════════════════════════════════════════════════
//
// U9.Q7 = CLASS      (0=ALU/reg, 1=MEM/BRANCH)
// U9.Q6 = ALU_OP2 ─┐
// U9.Q5 = ALU_OP1 ─┼─ ALU operation (000=ADD 001=SUB 010=AND...)
// U9.Q4 = ALU_OP0 ─┘
// U9.Q3 = IMM_MODE  (1=operand byte on IBUS, 0=register on IBUS)
// U9.Q2 = AC_WR     (1=latch ALU result into AC)
// U9.Q1 = REG_WR    (1=latch IBUS into r[rd] via U20)
// U9.Q0 = AC_TO_BUS (1=U25 drives AC onto IBUS)
//
// These 8 bits replace TWO microcode ROMs + step counter from RV8!

// ═══════════════════════════════════════════════════════════════
// CYCLE TIMING
// ═══════════════════════════════════════════════════════════════
//
// Cycle 1 (STATE=0): FETCH CONTROL
//   PC → ROM → D[7:0] = control byte
//   IR_HIGH (U9) latches on CLK↑
//   PC increments
//   IBUS idle (U19 disabled: STATE=0)
//
// Cycle 2 (STATE=1): FETCH OPERAND + EXECUTE
//   PC → ROM → D[7:0] = operand byte
//   IR_LOW (U10) latches on CLK↑
//   IR_HIGH outputs ACTIVE → drive hardware:
//     U19 enabled (STATE=1) → selected register drives IBUS
//     OR: U10 /OE=LOW (IMM_MODE=1) → operand drives IBUS
//     OR: U25 /OE=LOW (AC_TO_BUS=1) → AC drives IBUS
//   ALU computes: AC + IBUS (via XOR) → result
//   On CLK↑: AC latches (if AC_WR=1), register latches (if REG_WR=1)
//   PC increments, STATE toggles back to 0

// ═══════════════════════════════════════════════════════════════
// SUMMARY: How buses connect
// ═══════════════════════════════════════════════════════════════
//
//  ┌─────────────────────────────────────────────────────────┐
//  │              ALU_A (hardwired, always active)            │
//  │  Driver: U1 Q[7:0] (AC, /OE=GND)                       │
//  │  Consumers: U11 A[3:0], U12 A[7:4] (adder A inputs)    │
//  │             U25 A[7:0] (AC→IBUS buffer inputs)          │
//  └─────────────────────────────────────────────────────────┘
//
//  ┌─────────────────────────────────────────────────────────┐
//  │                    IBUS (internal 8-bit)                 │
//  │  Drivers: registers(U2-U8), operand(U10),               │
//  │           AC_buffer(U25), RAM_buffer(U22)               │
//  │  Consumers: registers(U2-U8), XOR→ALU_B(U13-U14),      │
//  │             RAM_buffer(U22)                              │
//  └────────────────────────┬────────────────────────────────┘
//                           │ U22 (74HC245) bridges
//                           ▼
//  ┌─────────────────────────────────────────────────────────┐
//  │              RV8-Bus (external 40-pin)                   │
//  │  A[15:0]: from PC(U15-U18) or register (via U24 mux)   │
//  │  D[7:0]:  ↔ U22 ↔ IBUS                                 │
//  │  /RD,/WR: from control logic                            │
//  │  Connects to: RAM, peripherals                          │
//  └─────────────────────────────────────────────────────────┘
//
//  ┌─────────────────────────────────────────────────────────┐
//  │              ROM Data Bus (dedicated 8-bit)              │
//  │  Driver: SST39SF010A D[7:0] (always outputting)         │
//  │  Consumers: U9 D[7:0] (IR_HIGH), U10 D[7:0] (IR_LOW)  │
//  │  NOT shared with IBUS — separate traces!                │
//  └─────────────────────────────────────────────────────────┘
//
// NO BUS CONFLICTS:
//   IBUS: only one driver active (control byte ensures mutual exclusion)
//   ALU_A: dedicated traces, no contention possible
//   ROM data: dedicated to IR latches, no contention
//   RV8-Bus addr: PC or register (U24 mux, never both)
//   RV8-Bus data: RAM read or CPU write (U22 direction control)
//
// KEY DIFFERENCE FROM RV8:
//   RV8: microcode ROM sequences 4-6 steps per instruction
//   RV8-W: control byte IS the instruction — 2 cycles, done.
//   RV8: AC on IBUS like other registers
//   RV8-W: AC hardwired to ALU A, needs U25 buffer for IBUS access
```

---

*25 logic + SST39SF010A + 62256 = 27 packages. No microcode. 2 cycles/instruction.*
