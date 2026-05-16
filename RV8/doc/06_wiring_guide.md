{
// ═══════════════════════════════════════════════════════════════
// RV8 CPU — WiringGuide (Bus-Centric)
// 27 logic chips + ROM + RAM = 29 packages
//
// TWO BUSES:
//   RV8-Bus (external, 40-pin): A[15:0] + D[7:0] → ROM, RAM, peripherals
//   IBUS (internal, 8-bit): connects all CPU chips together
//
// U22 (74HC245) bridges IBUS ↔ RV8-Bus D[7:0]
// ═══════════════════════════════════════════════════════════════

Project: RV8,

// ═══════════════════════════════════════════════════════════════
// RV8-Bus (EXTERNAL) — 40-pin connector to ROM, RAM, peripherals
// ═══════════════════════════════════════════════════════════════

RV8_Bus:{
    // --- Address (directly to ROM + RAM address pins) ---
    A0:  U16.Q0 or U18.Q0,  // PC low or addr latch low (selected by /OE)
    A1:  U16.Q1 or U18.Q1,
    A2:  U16.Q2 or U18.Q2,
    A3:  U16.Q3 or U18.Q3,
    A4:  U16.Q4 or U18.Q4,
    A5:  U16.Q5 or U18.Q5,
    A6:  U16.Q6 or U18.Q6,
    A7:  U16.Q7 or U18.Q7,
    A8:  U17.Q0 or U19.Q0,  // PC high or addr latch high
    A9:  U17.Q1 or U19.Q1,
    A10: U17.Q2 or U19.Q2,
    A11: U17.Q3 or U19.Q3,
    A12: U17.Q4 or U19.Q4,
    A13: U17.Q5 or U19.Q5,
    A14: U17.Q6 or U19.Q6,
    A15: U17.Q7 or U19.Q7,
    // PC (U16+U17) drives when PC_ADDR=1 (/OE=LOW)
    // Addr latches (U18+U19) drive when PC_ADDR=0 (/OE=LOW)
    // Never both at same time!

    // --- Data (bridged to IBUS via U22) ---
    D0: U22.B1,  D1: U22.B2,  D2: U22.B3,  D3: U22.B4,
    D4: U22.B5,  D5: U22.B6,  D6: U22.B7,  D7: U22.B8,

    // --- Control ---
    "/RD": from_microcode (U23.D0),  // → ROM./OE + RAM./OE
    "/WR": from_microcode (U23.D1),  // → RAM./WE
    CLK:  crystal_oscillator,
    "/RST": reset_circuit,
    "/NMI": pull-up_10K (reserved),
    "/IRQ": pull-up_10K → U23.A13 (Flash address bit),
    HALT: (reserved),
    SYNC: from_microcode (step=0 detect),

    // --- 40-pin pinout ---
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
// Only ONE chip drives IBUS at a time (via /OE control)
// ═══════════════════════════════════════════════════════════════

IBUS:{
    width: 8,
    drivers: [
        "U1-U8 (registers, selected by U20 /OE decode)",
        "U10 (IR operand, when OPR_OE=LOW)",
        "U22 (bus buffer, when reading from RV8-Bus → IBUS)",
        "U25 (ALU result latch, when ALUR_OE=LOW)"
    ],
    consumers: [
        "U9 (IR opcode, latches on IR_CLK)",
        "U10 (IR operand, latches on OPR_CLK)",
        "U11 (ALU B latch, latches on ALUB_CLK)",
        "U18 (addr latch low, latches on ADDR_LO_CLK)",
        "U19 (addr latch high, latches on ADDR_HI_CLK)",
        "U22 (bus buffer, when writing IBUS → RV8-Bus)"
    ],
    rule: "Microcode ensures only ONE driver active per clock cycle"
},

// ═══════════════════════════════════════════════════════════════
// CHIPS ON IBUS (internal bus)
// ═══════════════════════════════════════════════════════════════

Part:{

    // --- REGISTERS (on IBUS) ---
    U1:{type:74HC574, bus:IBUS, function:"r0 (zero, never writes)",
        1:U20.Y0, 11:GND, "2-9":ALU_R, "12-19":IBUS, 10:GND, 20:VCC},
    U2:{type:74HC574, bus:IBUS, function:"r1 (a0)",
        1:U20.Y1, 11:U21.Y1, "2-9":ALU_R, "12-19":IBUS, 10:GND, 20:VCC},
    U3:{type:74HC574, bus:IBUS, function:"r2 (a1)",
        1:U20.Y2, 11:U21.Y2, "2-9":ALU_R, "12-19":IBUS, 10:GND, 20:VCC},
    U4:{type:74HC574, bus:IBUS, function:"r3 (t0)",
        1:U20.Y3, 11:U21.Y3, "2-9":ALU_R, "12-19":IBUS, 10:GND, 20:VCC},
    U5:{type:74HC574, bus:IBUS, function:"r4 (t1)",
        1:U20.Y4, 11:U21.Y4, "2-9":ALU_R, "12-19":IBUS, 10:GND, 20:VCC},
    U6:{type:74HC574, bus:IBUS, function:"r5 (s0)",
        1:U20.Y5, 11:U21.Y5, "2-9":ALU_R, "12-19":IBUS, 10:GND, 20:VCC},
    U7:{type:74HC574, bus:IBUS, function:"r6 (s1)",
        1:U20.Y6, 11:U21.Y6, "2-9":ALU_R, "12-19":IBUS, 10:GND, 20:VCC},
    U8:{type:74HC574, bus:IBUS, function:"r7 (sp/ra)",
        1:U20.Y7, 11:U21.Y7, "2-9":ALU_R, "12-19":IBUS, 10:GND, 20:VCC},
    // /OE(1) from U20 (read decode) — selects who drives IBUS
    // CLK(11) from U21 (write decode) — selects who latches from ALU_R
    // D(2-9) from ALU_R bus (result latch output)
    // Q(12-19) to IBUS (when /OE=LOW)

    // --- IR (on IBUS, latches from IBUS) ---
    U9:{type:74HC574, bus:IBUS, function:"IR opcode",
        1:GND, 11:IR_CLK, "2-9":IBUS, "12-19":"→Flash_addr+decode", 10:GND, 20:VCC},
    U10:{type:74HC574, bus:IBUS, function:"IR operand (also drives IBUS for immediate)",
        1:OPR_OE, 11:OPR_CLK, "2-9":IBUS, "12-19":IBUS, 10:GND, 20:VCC},

    // --- ALU B LATCH (on IBUS, latches from IBUS) ---
    U11:{type:74HC574, bus:IBUS, function:"ALU B latch",
        1:VCC, 11:ALUB_CLK, "2-9":IBUS, "12-19":"→XOR(U14+U15)→Adder_B", 10:GND, 20:VCC},
    // /OE=VCC (never drives IBUS), Q→ALU B input via XOR

    // --- ALU (internal, not on IBUS directly) ---
    U12:{type:74HC283, bus:internal, function:"ALU adder low nibble",
        "A1-A4":"IBUS[3:0] (rd value)", "B1-B4":"XOR_out[3:0]",
        C0:ALU_SUB, "S1-S4":"→U25.D[3:0]", C4:"→U13.C0"},
    U13:{type:74HC283, bus:internal, function:"ALU adder high nibble",
        "A1-A4":"IBUS[7:4] (rd value)", "B1-B4":"XOR_out[7:4]",
        C0:"U12.C4", "S1-S4":"→U25.D[7:4]", C4:"carry_out→U24.D2"},
    U14:{type:74HC86, bus:internal, function:"XOR low (SUB invert bits 0-3)",
        "inputs":"U11.Q[3:0] XOR ALU_SUB", "outputs":"→U12.B[3:0]"},
    U15:{type:74HC86, bus:internal, function:"XOR high (SUB invert bits 4-7)",
        "inputs":"U11.Q[7:4] XOR ALU_SUB", "outputs":"→U13.B[7:4]"},

    // --- ALU RESULT LATCH (drives IBUS when needed, always drives ALU_R) ---
    U25:{type:74HC574, bus:IBUS, function:"ALU result latch → ALU_R bus",
        1:GND, 11:ALUR_CLK, "2-9":"adder_S[7:0]", "12-19":"ALU_R[7:0]→all_reg_D", 10:GND, 20:VCC},
    // /OE=GND (always drives ALU_R bus to register D inputs)

    // --- CHIPS ON RV8-Bus (address bus) ---

    // --- PC (drives RV8-Bus A[15:0] during fetch) ---
    U16:{type:74HC574, bus:RV8_Bus_addr, function:"PC low (A[7:0] during fetch)",
        1:PC_ADDR_n, 11:PC_LO_CLK, "2-9":ALU_R, "12-19":"A[7:0]", 10:GND, 20:VCC},
    U17:{type:74HC574, bus:RV8_Bus_addr, function:"PC high (A[15:8] during fetch)",
        1:PC_ADDR_n, 11:PC_HI_CLK, "2-9":ALU_R, "12-19":"A[15:8]", 10:GND, 20:VCC},
    // /OE=PC_ADDR_n: LOW during fetch (PC drives address), HIGH during data access
    // D from ALU_R (PC+1 computed by ALU, or branch target)

    // --- ADDRESS LATCHES (drive RV8-Bus A[15:0] during data access) ---
    U18:{type:74HC574, bus:RV8_Bus_addr, function:"Addr latch low (A[7:0] during data)",
        1:PC_ADDR, 11:ADDR_LO_CLK, "2-9":IBUS, "12-19":"A[7:0]", 10:GND, 20:VCC},
    U19:{type:74HC574, bus:RV8_Bus_addr, function:"Addr latch high (A[15:8] during data)",
        1:PC_ADDR, 11:ADDR_HI_CLK, "2-9":IBUS, "12-19":"A[15:8]", 10:GND, 20:VCC},
    // /OE=PC_ADDR: LOW during data access (latches drive), HIGH during fetch
    // D from IBUS (register value for memory address)

    // --- BUS BRIDGE (connects IBUS ↔ RV8-Bus D[7:0]) ---
    U22:{type:74HC245, bus:both, function:"Bridge: IBUS ↔ RV8-Bus data",
        1:BUF_DIR, 19:BUF_OE_n,
        "2-9":"IBUS[7:0] (A side)", "11-18":"D[7:0] (B side, RV8-Bus)",
        10:GND, 20:VCC},
    // DIR(1): 0=B→A (read: RV8-Bus→IBUS), 1=A→B (write: IBUS→RV8-Bus)
    // /OE(19): LOW=enabled (only during memory access steps)

    // --- CONTROL (not on either bus — generates control signals) ---

    U20:{type:74HC138, bus:control, function:"Register READ select (who drives IBUS)",
        "A,B,C":"from operand rs[2:0] or microcode", G1:REG_RD_EN,
        "Y0-Y7":"→U1-U8 /OE pins"},

    U21:{type:74HC138, bus:control, function:"Register WRITE select (who latches ALU_R)",
        "A,B,C":"from opcode rd[2:0]", G1:REG_WR_EN,
        "Y0-Y7":"→U1-U8 CLK pins"},

    U23:{type:SST39SF010A, bus:control, function:"Microcode Flash #1 (low control byte)",
        "addr":"step[2:0]+opcode[7:0]+flags[1:0]+IRQ = 14 bits",
        "data":"D[7:0] = BUF_OE,BUF_DIR,PC_ADDR,ADDR_CLK,PC_INC,IR_CLK,OPR_CLK,STEP_RST"},

    U27:{type:SST39SF010A, bus:control, function:"Microcode Flash #2 (high control byte)",
        "addr":"same as U23 (parallel wired)",
        "data":"D[7:0] = REG_RD_EN,REG_WR_EN,ALUB_CLK,ALUR_CLK,ALU_SUB,FLAGS_CLK,PC_LOAD,ADDR_HI"},

    U24:{type:74HC74, bus:control, function:"Flags (Z, C)",
        "FF1":"D=alu_zero, CLK=FLAGS_CLK, Q=flag_z → Flash addr",
        "FF2":"D=carry_out, CLK=FLAGS_CLK, Q=flag_c → Flash addr"},

    U26:{type:74HC161, bus:control, function:"Step counter (sequences micro-steps)",
        CLK:CLK, "/CLR":STEP_RST_n, "Q[2:0]":"→Flash addr A[10:8]"},

    // --- MEMORY (on RV8-Bus) ---
    ROM:{type:AT28C256, bus:RV8_Bus, function:"Program ROM",
        "A[14:0]":"from RV8-Bus A[14:0]", "D[7:0]":"to RV8-Bus D[7:0]",
        "/CE":"A15 or decode", "/OE":"/RD", "/WE":VCC},
    RAM:{type:62256, bus:RV8_Bus, function:"Data RAM",
        "A[14:0]":"from RV8-Bus A[14:0]", "D[7:0]":"↔ RV8-Bus D[7:0]",
        "/CE":"not A15 or decode", "/OE":"/RD", "/WE":"/WR"},

    // --- SUPPORT ---
    OSC:{type:"Crystal 3.5/10MHz", output:CLK},
    R1:{type:"10K", 1:VCC, 2:"/RST"},
    SW:{type:"Pushbutton", 1:"/RST", 2:GND},
    C1:{type:"100nF", 1:"/RST", 2:GND}
    }
}

// ═══════════════════════════════════════════════════════════════
// SUMMARY: How buses connect
// ═══════════════════════════════════════════════════════════════
//
//  ┌─────────────────────────────────────────────────────────┐
//  │                    IBUS (internal 8-bit)                  │
//  │  Drivers: registers(U1-U8), operand(U10), buffer(U22)   │
//  │  Consumers: IR(U9), operand(U10), ALU_B(U11),           │
//  │             addr_lo(U18), addr_hi(U19), buffer(U22)     │
//  └────────────────────────┬────────────────────────────────┘
//                           │ U22 (74HC245) bridges
//                           ▼
//  ┌─────────────────────────────────────────────────────────┐
//  │              RV8-Bus (external 40-pin)                    │
//  │  A[15:0]: from PC(U16+U17) or addr_latch(U18+U19)      │
//  │  D[7:0]:  ↔ U22 ↔ IBUS                                 │
//  │  /RD,/WR: from microcode                                │
//  │  Connects to: ROM, RAM, Programmer, Trainer, peripherals│
//  └─────────────────────────────────────────────────────────┘
//
// NO BUS CONFLICTS:
//   IBUS: only one /OE active (microcode ensures)
//   RV8-Bus addr: PC or latches (never both, controlled by PC_ADDR signal)
//   RV8-Bus data: ROM/RAM output or CPU write (controlled by /RD, /WR)
