// ═══════════════════════════════════════════════════════════════
// RV8-S CPU — WiringGuide (Bus-Centric)
// 20 logic chips + ROM + RAM = 22 packages
//
// THREE BUSES:
//   RV8-Bus (external, 40-pin): A[15:0] + D[7:0] → ROM, RAM, peripherals
//   IBUS (internal, 8-bit): fetch path (ROM data → IR) and memory access
//   SBUS (internal, 1-bit serial): ALU operations (register → ALU → register)
//
// U22 (74HC245) bridges IBUS ↔ RV8-Bus D[7:0]
// Fetch is parallel (PC→ROM→IR via IBUS, same as RV8)
// Execute is serial (8 shift clocks per ALU operation via SBUS)
// ═══════════════════════════════════════════════════════════════

Project: RV8-S,

// ═══════════════════════════════════════════════════════════════
// RV8-Bus (EXTERNAL) — 40-pin connector to ROM, RAM, peripherals
// Same pinout as RV8 (fully compatible)
// ═══════════════════════════════════════════════════════════════

RV8_Bus:{
    // --- Address (from PC counters, directly to ROM + RAM) ---
    A0:  U14.Q0,   A1:  U14.Q1,   A2:  U14.Q2,   A3:  U14.Q3,
    A4:  U15.Q0,   A5:  U15.Q1,   A6:  U15.Q2,   A7:  U15.Q3,
    A8:  U16.Q0,   A9:  U16.Q1,   A10: U16.Q2,   A11: U16.Q3,
    A12: U17.Q0,   A13: U17.Q1,   A14: U17.Q2,   A15: U17.Q3,
    // PC (U14-U17) always drives address bus
    // For data access: register parallel out → PC load → address

    // --- Data (bridged to IBUS via U22) ---
    D0: U22.B1,  D1: U22.B2,  D2: U22.B3,  D3: U22.B4,
    D4: U22.B5,  D5: U22.B6,  D6: U22.B7,  D7: U22.B8,

    // --- Control ---
    "/RD": from_microcode (U19),   // → ROM./OE + RAM./OE
    "/WR": from_microcode (U19),   // → RAM./WE
    CLK:  crystal_oscillator,
    "/RST": reset_circuit,
    "/NMI": pull-up_10K (reserved),
    "/IRQ": pull-up_10K → U19 address bit,
    HALT: (reserved),
    SYNC: from_microcode (step=0 detect),

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
// IBUS (INTERNAL) — 8-bit parallel bus for fetch + memory access
// Used during FETCH phase (parallel, same as RV8)
// ═══════════════════════════════════════════════════════════════

IBUS:{
    width: 8,
    drivers: [
        "U22 (245 bus buffer, when reading RV8-Bus → IBUS)"
    ],
    consumers: [
        "U9 (IR opcode, latches on IR_CLK)",
        "U10 (IR operand, latches on OPR_CLK)",
        "U22 (bus buffer, when writing IBUS → RV8-Bus)"
    ],
    rule: "Only active during fetch/memory phases. ROM data → U22 → IBUS → IR latches."
},

// ═══════════════════════════════════════════════════════════════
// SBUS (INTERNAL) — 1-bit serial bus for ALU operations
// Used during EXECUTE phase (8 shift clocks per operation)
// ═══════════════════════════════════════════════════════════════

SBUS:{
    width: 1,
    path: "Register QH' → ALU (U12+U13+U11) → Result → Register SER",
    signals: [
        "SER_A: source register QH' output (selected by U18)",
        "SER_B: second register QH' output (selected by U18)",
        "SER_R: ALU sum output → destination register SER input",
        "CARRY: U11 FF output → ALU carry input"
    ],
    rule: "8 shift clocks per byte. LSB first. Carry FF reset at start of operation."
},

// ═══════════════════════════════════════════════════════════════
// CHIPS ON SBUS (serial ALU chain)
// ═══════════════════════════════════════════════════════════════

Part:{

    // --- REGISTERS r0-r7 (on SBUS) — 74HC595 ×8 ---
    // Serial chain: SER(14)=input, QH'(9)=output, SRCLK(11)=shift, RCLK(12)=latch
    // Parallel outputs QA-QH available for address/data bus access

    U1:{type:74HC595, bus:SBUS, function:"r0 (zero — SER tied LOW)",
        14:GND, 9:QH_R0, 11:SRCLK, 12:RCLK, 13:GND, 10:/RST,
        "QA-QH":"parallel out (always 0x00)", 16:VCC, 8:GND},
    // SER=GND → always shifts in 0, r0 stays zero

    U2:{type:74HC595, bus:SBUS, function:"r1 (a0)",
        14:SER_R, 9:QH_R1, 11:SRCLK, 12:RCLK, 13:GND, 10:/RST,
        "QA-QH":"parallel out", 16:VCC, 8:GND},

    U3:{type:74HC595, bus:SBUS, function:"r2 (a1)",
        14:SER_R, 9:QH_R2, 11:SRCLK, 12:RCLK, 13:GND, 10:/RST,
        "QA-QH":"parallel out", 16:VCC, 8:GND},

    U4:{type:74HC595, bus:SBUS, function:"r3 (t0)",
        14:SER_R, 9:QH_R3, 11:SRCLK, 12:RCLK, 13:GND, 10:/RST,
        "QA-QH":"parallel out", 16:VCC, 8:GND},

    U5:{type:74HC595, bus:SBUS, function:"r4 (t1)",
        14:SER_R, 9:QH_R4, 11:SRCLK, 12:RCLK, 13:GND, 10:/RST,
        "QA-QH":"parallel out", 16:VCC, 8:GND},

    U6:{type:74HC595, bus:SBUS, function:"r5 (s0)",
        14:SER_R, 9:QH_R5, 11:SRCLK, 12:RCLK, 13:GND, 10:/RST,
        "QA-QH":"parallel out", 16:VCC, 8:GND},

    U7:{type:74HC595, bus:SBUS, function:"r6 (s1)",
        14:SER_R, 9:QH_R6, 11:SRCLK, 12:RCLK, 13:GND, 10:/RST,
        "QA-QH":"parallel out", 16:VCC, 8:GND},

    U8:{type:74HC595, bus:SBUS, function:"r7 (ra/sp)",
        14:SER_R, 9:QH_R7, 11:SRCLK, 12:RCLK, 13:GND, 10:/RST,
        "QA-QH":"parallel out", 16:VCC, 8:GND},
    // All U1-U8: /OE(13)=GND (parallel outputs always active)
    // SRCLK(11) gated by microcode (only selected register shifts)
    // RCLK(12) pulses after 8 shifts to update parallel outputs
    // SER(14) = ALU result (SER_R) for destination register
    // QH'(9) = serial output → U18 mux → ALU input

    // --- ALU (on SBUS) — 1-bit serial full adder ---

    U11:{type:74HC74, bus:SBUS, function:"Carry FF (stores carry between bit positions)",
        1:/RST, 2:CARRY_D, 3:SRCLK, 4:VCC, 5:CARRY, 6:CARRY_n, 7:GND,
        8:nc, 9:nc, 10:VCC, 11:nc, 12:nc, 13:/RST, 14:VCC},
    // FF1: D=CARRY_D (next carry), CLK=SRCLK, Q=CARRY → U12 pin 5
    // /PRE=VCC, /CLR=/RST (cleared at start of ALU operation)

    U12:{type:74HC86, bus:SBUS, function:"XOR gates (sum + SUB invert)",
        1:SER_B, 2:ALU_SUB, 3:SER_B_INV,       // Gate1: B XOR SUB → B_inv
        4:SER_A, 5:SER_B_INV, 6:A_XOR_B,       // Gate2: A XOR B_inv → partial sum
        7:GND,
        8:A_XOR_B, 9:CARRY, 10:SER_R,          // Gate3: partial XOR carry → SUM (result)
        11:nc, 12:nc, 13:nc, 14:VCC},
    // Gate1: SUB invert (B XOR ALU_SUB)
    // Gate2: A XOR B_inv → A_XOR_B
    // Gate3: A_XOR_B XOR CARRY → SER_R (final sum bit → dest register SER)
    // Gate4: spare

    U13:{type:74HC08, bus:SBUS, function:"AND gates (carry generation)",
        1:SER_A, 2:SER_B_INV, 3:A_AND_B,       // Gate1: A AND B_inv
        4:CARRY, 5:A_XOR_B, 6:C_AND_AXB,       // Gate2: CARRY AND A_XOR_B
        7:GND,
        8:nc, 9:nc, 10:nc,                      // Gate3: spare
        11:nc, 12:nc, 13:nc, 14:VCC},
    // CARRY_D = A_AND_B OR C_AND_AXB (OR provided by diode-OR or spare gate)
    // Carry-out: use diode-OR (D1: A_AND_B→CARRY_D, D2: C_AND_AXB→CARRY_D)
    //   with pull-down resistor. No extra chip needed.

    // ═══════════════════════════════════════════════════════════════
    // CHIPS ON IBUS (parallel fetch path)
    // ═══════════════════════════════════════════════════════════════

    // --- IR (on IBUS, latches from IBUS during fetch) ---

    U9:{type:74HC574, bus:IBUS, function:"IR opcode (parallel latch from ROM)",
        1:GND, 11:IR_CLK, "2-9":"IBUS[7:0]", "12-19":"→U19 Flash addr (opcode field)",
        10:GND, 20:VCC},
    // /OE=GND (always drives to Flash address), CLK=IR_CLK
    // D from IBUS (ROM data via U22), Q → microcode Flash address

    U10:{type:74HC574, bus:IBUS, function:"IR operand (parallel latch from ROM)",
        1:GND, 11:OPR_CLK, "2-9":"IBUS[7:0]", "12-19":"→U18 reg select + immediate",
        10:GND, 20:VCC},
    // Q[7:5]=rs field → U18 register select mux address
    // Q[4:0]=immediate value (for ADDI, branch offset, etc.)

    // --- BUS BRIDGE (connects IBUS ↔ RV8-Bus D[7:0]) ---

    U22:{type:74HC245, bus:"IBUS↔RV8-Bus", function:"Bridge: IBUS ↔ RV8-Bus data",
        1:BUF_DIR, 19:BUF_OE_n,
        "2-9":"IBUS[7:0] (A side)", "11-18":"D[7:0] (B side, RV8-Bus)",
        10:GND, 20:VCC},
    // DIR(1): 0=B→A (read: RV8-Bus→IBUS), 1=A→B (write: IBUS→RV8-Bus)
    // /OE(19): LOW=enabled (only during fetch/memory access steps)

    // ═══════════════════════════════════════════════════════════════
    // CHIPS ON RV8-Bus (address bus)
    // ═══════════════════════════════════════════════════════════════

    // --- PC (drives RV8-Bus A[15:0]) — 74HC161 ×4 ---

    U14:{type:74HC161, bus:RV8_Bus, function:"PC bits 3:0",
        1:/RST, 2:CLK, 3:PC_D0, 4:PC_D1, 5:PC_D2, 6:PC_D3,
        7:PC_ENT, 8:GND, 9:PC_LD_n, 10:PC_ENP,
        11:A3, 12:A2, 13:A1, 14:A0, 15:"→U15.ENT", 16:VCC},

    U15:{type:74HC161, bus:RV8_Bus, function:"PC bits 7:4",
        1:/RST, 2:CLK, 3:PC_D4, 4:PC_D5, 5:PC_D6, 6:PC_D7,
        7:"U14.RCO", 8:GND, 9:PC_LD_n, 10:PC_ENP,
        11:A7, 12:A6, 13:A5, 14:A4, 15:"→U16.ENT", 16:VCC},

    U16:{type:74HC161, bus:RV8_Bus, function:"PC bits 11:8",
        1:/RST, 2:CLK, 3:PC_D8, 4:PC_D9, 5:PC_D10, 6:PC_D11,
        7:"U15.RCO", 8:GND, 9:PC_LD_n, 10:PC_ENP,
        11:A11, 12:A10, 13:A9, 14:A8, 15:"→U17.ENT", 16:VCC},

    U17:{type:74HC161, bus:RV8_Bus, function:"PC bits 15:12",
        1:/RST, 2:CLK, 3:PC_D12, 4:PC_D13, 5:PC_D14, 6:PC_D15,
        7:"U16.RCO", 8:GND, 9:PC_LD_n, 10:PC_ENP,
        11:A15, 12:A14, 13:A13, 14:A12, 15:nc, 16:VCC},
    // PC increments on PC_INC (ENT+ENP high)
    // PC loads branch target on PC_LD_n=LOW (from register parallel outputs)

    // ═══════════════════════════════════════════════════════════════
    // CONTROL (not on data buses — generates control signals)
    // ═══════════════════════════════════════════════════════════════

    // --- REGISTER SELECT MUX (selects which QH' feeds SBUS) ---

    U18:{type:74HC151, bus:control, function:"8:1 mux — register serial output select",
        "S0,S1,S2":"REG_SEL[2:0] from U10 operand or microcode",
        "I0-I7":"QH_R0..QH_R7 (serial outputs from U1-U8)",
        Y:"→SER_B (ALU B input via U12)",
        "/E":GND, 16:VCC, 8:GND},
    // Selects one of 8 register serial outputs to feed ALU input B
    // REG_SEL comes from IR operand rs[2:0] field

    // --- MICROCODE FLASH ---

    U19:{type:SST39SF010A, bus:control, function:"Microcode Flash (sequences all operations)",
        "addr[13:0]":"{step[3:0], opcode[7:0], flags[1:0]}",
        "data[7:0]":"control signals per micro-step",
        // Control outputs:
        //   D0: SRCLK_EN (enable shift clock to selected register)
        //   D1: ALU_SUB (invert B for subtract)
        //   D2: PC_INC (increment PC)
        //   D3: IR_CLK (latch opcode from IBUS)
        //   D4: OPR_CLK (latch operand from IBUS)
        //   D5: BUF_OE_n (enable U22 bus buffer)
        //   D6: MEM_RD (/RD to ROM/RAM)
        //   D7: STEP_RST (reset step counter = end of instruction)
        32:VCC, 16:GND},

    // ═══════════════════════════════════════════════════════════════
    // MEMORY (on RV8-Bus)
    // ═══════════════════════════════════════════════════════════════

    ROM:{type:AT28C256, bus:RV8_Bus, function:"Program ROM",
        "A[14:0]":"from RV8-Bus A[14:0]", "D[7:0]":"→ RV8-Bus D[7:0]",
        "/CE":"A15_decode (low 32K)", "/OE":"/RD", "/WE":VCC},

    RAM:{type:62256, bus:RV8_Bus, function:"Data RAM",
        "A[14:0]":"from RV8-Bus A[14:0]", "D[7:0]":"↔ RV8-Bus D[7:0]",
        "/CE":"A15_decode (high 32K)", "/OE":"/RD", "/WE":"/WR"},

    // ═══════════════════════════════════════════════════════════════
    // SUPPORT
    // ═══════════════════════════════════════════════════════════════

    OSC:{type:"Crystal 10MHz", output:CLK},
    R1:{type:"10K", 1:VCC, 2:"/RST"},
    SW:{type:"Pushbutton", 1:"/RST", 2:GND},
    C1:{type:"100nF", 1:"/RST", 2:GND},
    D1:{type:"1N4148", anode:"U13.pin3 (A_AND_B)", cathode:CARRY_D},
    D2:{type:"1N4148", anode:"U13.pin6 (C_AND_AXB)", cathode:CARRY_D},
    R2:{type:"10K", 1:CARRY_D, 2:GND}
    // D1+D2+R2 = diode-OR for carry generation (no extra chip needed)
}

// ═══════════════════════════════════════════════════════════════
// CHIP COUNT SUMMARY
// ═══════════════════════════════════════════════════════════════
//
//  SBUS chips:  U1-U8 (595×8), U11 (74), U12 (86), U13 (08) = 11
//  IBUS chips:  U9-U10 (574×2), U22 (245)                    = 3
//  RV8-Bus:     U14-U17 (161×4)                               = 4
//  Control:     U18 (151), U19 (Flash)                        = 2
//  ─────────────────────────────────────────────────────────────
//  Total logic: 20 chips + ROM + RAM = 22 packages
//
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// SUMMARY: How buses connect
// ═══════════════════════════════════════════════════════════════
//
//  ┌─────────────────────────────────────────────────────────┐
//  │              SBUS (internal, 1-bit serial)               │
//  │  Path: Register QH' → U18 mux → ALU → Register SER     │
//  │  Chips: U1-U8 (595 registers), U11 (carry FF),          │
//  │         U12 (XOR sum), U13 (AND carry), U18 (mux)       │
//  │  Active during: EXECUTE phase (8 clocks per operation)   │
//  └─────────────────────────────────────────────────────────┘
//
//  ┌─────────────────────────────────────────────────────────┐
//  │              IBUS (internal, 8-bit parallel)             │
//  │  Path: U22 (from RV8-Bus) → IR (U9, U10)               │
//  │  Active during: FETCH phase (ROM data → IR latches)     │
//  └────────────────────────┬────────────────────────────────┘
//                           │ U22 (74HC245) bridges
//                           ▼
//  ┌─────────────────────────────────────────────────────────┐
//  │              RV8-Bus (external, 40-pin)                  │
//  │  A[15:0]: from PC (U14-U17, 74HC161 counters)           │
//  │  D[7:0]:  ↔ U22 ↔ IBUS                                 │
//  │  /RD,/WR: from microcode (U19)                          │
//  │  Connects to: ROM, RAM, peripherals (same as RV8)       │
//  └─────────────────────────────────────────────────────────┘
//
// DATA FLOW:
//   FETCH:   PC→ROM→D[7:0]→U22→IBUS→IR (parallel, 2 cycles)
//   EXECUTE: Reg.QH'→U18→ALU→Reg.SER (serial, 8 clocks)
//   STORE:   After 8 shifts, RCLK updates register parallel outputs
//   MEMORY:  Register parallel out → PC load → address → RAM ↔ U22 ↔ IBUS
//
// NO BUS CONFLICTS:
//   IBUS: only active during fetch/memory (U22 /OE controls)
//   SBUS: only active during execute (SRCLK gated by microcode)
//   RV8-Bus: PC always drives address; data controlled by /RD, /WR
