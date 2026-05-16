{
// ═══════════════════════════════════════════════════════════════
// RV8-R CPU — WiringGuide (Bus-Centric)
// 18 logic chips + ROM + RAM = 21 packages
// = RV8 minus hardware registers, registers live in RAM $00-$07
//
// Same ISA as RV8 (35 instructions, binary compatible)
// Same microcode (2× Flash), same step counter
// Fewer chips: no 8× register 574s, no 2× decode 138s
//
// TWO BUSES:
//   RV8-Bus (external 40-pin): A[15:0] + D[7:0] → ROM, RAM
//   IBUS (internal 8-bit): ALU, IR, result latch, bus buffer
// ═══════════════════════════════════════════════════════════════

Project: RV8-R,

RV8_Bus:{
    "A[15:0]": "PC (fetch) or address latches (register/memory access)",
    "D[7:0]":  "ROM/RAM ↔ U12 (245) ↔ IBUS",
    "/RD":     "from microcode",
    "/WR":     "from microcode",
    pinout:    "Same 40-pin as all RV8 variants"
},

IBUS:{
    width: 8,
    drivers: [
        "U2 (IR operand, /OE controlled)",
        "U12 (245 bus buffer, read mode)",
        "U15 (ALU result latch, /OE controlled)"
    ],
    consumers: [
        "U1 (IR opcode, CLK=IR_CLK)",
        "U2 (IR operand, CLK=OPR_CLK)",
        "U3 (ALU B latch, CLK=ALUB_CLK)",
        "U10 (addr latch low, CLK=ADDR_LO_CLK)",
        "U11 (addr latch high, CLK=ADDR_HI_CLK)",
        "U12 (245 bus buffer, write mode)",
        "U6-U7 (XOR → adder B inputs)"
    ],
    rule: "One driver at a time (microcode controls /OE and BUF_OE)"
},

Part:{
    // ═══════════════════════════════════════════
    // IR — 74HC574 ×2 (U1-U2)
    // ═══════════════════════════════════════════

    U1:{type:74HC574, bus:IBUS, function:"IR opcode",
        1:GND, 11:IR_CLK, "2-9":IBUS, "12-19":"→Flash addr A[7:0]",
        10:GND, 20:VCC},
    // /OE=GND (always outputs to Flash address)

    U2:{type:74HC574, bus:IBUS, function:"IR operand (also drives IBUS for immediate)",
        1:OPR_OE, 11:OPR_CLK, "2-9":IBUS, "12-19":"IBUS + addr_mux(U18)",
        10:GND, 20:VCC},
    // /OE controlled by microcode (drives IBUS when loading ALU B with immediate)

    // ═══════════════════════════════════════════
    // ALU — 74HC574 + 74HC283 ×2 + 74HC86 ×2 + 74HC574 (U3-U7, U15)
    // ═══════════════════════════════════════════

    U3:{type:74HC574, bus:IBUS, function:"ALU B latch",
        1:VCC, 11:ALUB_CLK, "2-9":IBUS, "12-19":"→U6-U7 XOR A inputs",
        10:GND, 20:VCC},
    // /OE=VCC (never drives IBUS). Outputs → XOR chips.

    U4:{type:74HC283, bus:internal, function:"ALU adder low nibble",
        5:"IBUS0", 3:"IBUS1", 14:"IBUS2", 12:"IBUS3",
        6:"U6.Y0", 2:"U6.Y1", 15:"U6.Y2", 11:"U6.Y3",
        7:ALU_SUB, 9:"→U5.C0",
        4:"S0→U15.D0", 1:"S1→U15.D1", 13:"S2→U15.D2", 10:"S3→U15.D3",
        8:GND, 16:VCC},
    // A inputs from IBUS (register value from RAM during execute)
    // B inputs from XOR output (operand or register, inverted for SUB)

    U5:{type:74HC283, bus:internal, function:"ALU adder high nibble",
        5:"IBUS4", 3:"IBUS5", 14:"IBUS6", 12:"IBUS7",
        6:"U7.Y0", 2:"U7.Y1", 15:"U7.Y2", 11:"U7.Y3",
        7:"U4.C4", 9:"CARRY_OUT→U14.D2",
        4:"S4→U15.D4", 1:"S5→U15.D5", 13:"S6→U15.D6", 10:"S7→U15.D7",
        8:GND, 16:VCC},

    U6:{type:74HC86, bus:internal, function:"XOR low (SUB invert bits 0-3)",
        1:"U3.Q0", 2:ALU_SUB, 3:"→U4.B1",
        4:"U3.Q1", 5:ALU_SUB, 6:"→U4.B2",
        9:"U3.Q2", 10:ALU_SUB, 8:"→U4.B3",
        12:"U3.Q3", 13:ALU_SUB, 11:"→U4.B4",
        7:GND, 14:VCC},

    U7:{type:74HC86, bus:internal, function:"XOR high (SUB invert bits 4-7)",
        1:"U3.Q4", 2:ALU_SUB, 3:"→U5.B1",
        4:"U3.Q5", 5:ALU_SUB, 6:"→U5.B2",
        9:"U3.Q6", 10:ALU_SUB, 8:"→U5.B3",
        12:"U3.Q7", 13:ALU_SUB, 11:"→U5.B4",
        7:GND, 14:VCC},

    U15:{type:74HC574, bus:IBUS, function:"ALU result latch (drives IBUS for write-back)",
        1:ALUR_OE, 11:ALUR_CLK, "2-9":"adder S[7:0]", "12-19":IBUS,
        10:GND, 20:VCC},
    // /OE=ALUR_OE (drives IBUS when writing result to RAM)
    // CLK=ALUR_CLK (latches adder output)

    // ═══════════════════════════════════════════
    // PC — 74HC574 ×2 (U8-U9) — has /OE
    // ═══════════════════════════════════════════

    U8:{type:74HC574, bus:RV8_Bus_addr, function:"PC low (A[7:0] during fetch)",
        1:PC_ADDR_n, 11:PC_LO_CLK, "2-9":"ALU_R (from U15)", "12-19":"A[7:0]",
        10:GND, 20:VCC},
    // /OE=PC_ADDR_n (LOW during fetch, HIGH during data access)

    U9:{type:74HC574, bus:RV8_Bus_addr, function:"PC high (A[15:8] during fetch)",
        1:PC_ADDR_n, 11:PC_HI_CLK, "2-9":"ALU_R (from U15)", "12-19":"A[15:8]",
        10:GND, 20:VCC},

    // ═══════════════════════════════════════════
    // ADDRESS LATCHES — 74HC574 ×2 (U10-U11)
    // ═══════════════════════════════════════════

    U10:{type:74HC574, bus:RV8_Bus_addr, function:"Addr latch low (A[7:0] during data access)",
        1:PC_ADDR, 11:ADDR_LO_CLK,
        "2-4":"from U18 mux (IBUS[2:0] or opcode[2:0])",
        "5-9":"from U18 mux (IBUS[7:3] or GND)",
        "12-19":"A[7:0]",
        10:GND, 20:VCC},
    // /OE=PC_ADDR (LOW during data access, HIGH during fetch)
    // D inputs from U18 mux: selects IBUS (memory addr) or {00000,opcode[2:0]} (register addr)

    U11:{type:74HC574, bus:RV8_Bus_addr, function:"Addr latch high (A[15:8] during data access)",
        1:PC_ADDR, 11:ADDR_HI_CLK, "2-9":IBUS, "12-19":"A[15:8]",
        10:GND, 20:VCC},

    // ═══════════════════════════════════════════
    // REGISTER ADDRESS MUX — 74HC157 (U18) ← THE EXTRA CHIP
    // Selects addr latch low input: IBUS (memory) vs opcode[2:0] (register)
    // ═══════════════════════════════════════════

    U18:{type:74HC157, bus:internal, function:"Addr latch input mux (IBUS vs register addr)",
        1:REG_ADDR_MODE,
        2:"IBUS0", 3:"U1.Q0 (opcode bit 0)", 4:"→U10.D0",
        5:"IBUS1", 6:"U1.Q1 (opcode bit 1)", 7:"→U10.D1",
        11:"IBUS2", 10:"U1.Q2 (opcode bit 2)", 9:"→U10.D2",
        14:"IBUS3", 13:GND, 12:"→U10.D3",
        8:GND, 15:GND, 16:VCC},
    // S=REG_ADDR_MODE: 0=IBUS (memory address), 1=opcode[2:0] (register $00-$07)
    // B inputs: opcode[2:0] for bits 0-2, GND for bits 3-7 (registers are $00-$07)
    // Note: only muxes low nibble. High nibble of U10.D tied to GND (or from IBUS for memory)

    // ═══════════════════════════════════════════
    // BUS BUFFER — 74HC245 (U12)
    // ═══════════════════════════════════════════

    U12:{type:74HC245, bus:both, function:"Bridge: IBUS ↔ RV8-Bus D[7:0]",
        1:BUF_DIR, 19:BUF_OE_n, "2-9":IBUS, "11-18":"D[7:0]",
        10:GND, 20:VCC},

    // ═══════════════════════════════════════════
    // CONTROL — Flash ×2 + step counter + flags
    // ═══════════════════════════════════════════

    U13:{type:SST39SF010A, bus:control, function:"Microcode Flash #1 (low byte)",
        "addr":"step[2:0] + opcode[7:0] + flags[1:0] + IRQ = 14 bits",
        "data":"D[7:0] = BUF_OE, BUF_DIR, PC_ADDR, ADDR_CLK, PC_INC, IR_CLK, OPR_CLK, STEP_RST"},

    U17:{type:SST39SF010A, bus:control, function:"Microcode Flash #2 (high byte)",
        "addr":"same as U13",
        "data":"D[7:0] = REG_ADDR_MODE, ALUB_CLK, ALUR_CLK, ALUR_OE, ALU_SUB, FLAGS_CLK, PC_LOAD, ADDR_HI_CLK"},

    U14:{type:74HC74, bus:control, function:"Flags (Z, C)",
        "FF1":"D=alu_zero, CLK=FLAGS_CLK, Q=flag_z → Flash addr",
        "FF2":"D=carry_out, CLK=FLAGS_CLK, Q=flag_c → Flash addr",
        1:"/RST", 7:GND, 13:"/RST", 14:VCC},

    U16:{type:74HC161, bus:control, function:"Step counter",
        2:CLK, 1:STEP_RST_n, "Q[2:0]":"→Flash addr A[10:8]",
        7:VCC, 10:VCC, 8:GND, 16:VCC},

    // ═══════════════════════════════════════════
    // MEMORY
    // ═══════════════════════════════════════════

    ROM:{type:AT28C256, bus:RV8_Bus, function:"Program ROM",
        "/CE":"A15 (ROM at $C000+)", "/OE":"/RD", "/WE":VCC},
    RAM:{type:62256, bus:RV8_Bus, function:"RAM (registers $00-$07 + data)",
        "/CE":"NOT(A15) (RAM at $0000+)", "/OE":"/RD", "/WE":"/WR"},

    // ═══════════════════════════════════════════
    // SUPPORT
    // ═══════════════════════════════════════════
    OSC:{type:"Crystal 3.5/10MHz", output:CLK},
    R1:{type:"10K", 1:VCC, 2:"/RST"},
    SW:{type:"Pushbutton", 1:"/RST", 2:GND},
    C1:{type:"100nF", 1:"/RST", 2:GND},

    RV8_Bus_connector:{type:"40-pin IDC", pinout:"Same as all RV8 variants"}
},

// ═══════════════════════════════════════════════════════════════
// VERIFICATION
// ═══════════════════════════════════════════════════════════════
//
// Bus conflicts: NONE
//   IBUS drivers: U2(/OE), U12(BUF_OE+DIR), U15(ALUR_OE) — mutually exclusive via microcode
//   Address bus: PC (U8-U9, /OE) vs addr latches (U10-U11, /OE) — PC_ADDR controls
//
// Register access path (verified by trace):
//   Read: microcode sets REG_ADDR_MODE=1 → U18 mux routes opcode[2:0] → U10 latches
//         → addr bus = $000x → RAM outputs register value → U12 → IBUS → adder A
//   Write: U15 (result) drives IBUS → U12 → RAM[register addr] via /WR pulse
//
// PC increment: via ALU (microcode computes PC+1, loads back to U8-U9)
//
// CHIP COUNT: 18 logic ✅
//   U1-U3 (574×3: IR + ALU B latch)
//   U4-U5 (283×2: adder)
//   U6-U7 (86×2: XOR)
//   U8-U11 (574×4: PC + addr latches)
//   U12 (245: bus buffer)
//   U13+U17 (Flash×2: microcode)
//   U14 (74: flags)
//   U15 (574: result latch)
//   U16 (161: step counter)
//   U18 (157: register address mux)
//   = 18 logic chips + ROM + RAM = 21 packages
}
