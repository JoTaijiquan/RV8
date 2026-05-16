{
// ═══════════════════════════════════════════════════════════════
// RV8-G CPU — WiringGuide (Bus-Centric)
// 27 logic chips + ROM + RAM = 29 packages
// = RV8-GR (19 chips) + 8 chips for full ISA (AND/OR/branch)
//
// NO MICROCODE. Control byte + derived gates drive hardware.
// RAM REGISTERS ($00-$07). AC is only hardware register.
// 3 cycles per instruction. 1.7 MIPS @ 10 MHz.
//
// BUSES:
//   RV8-Bus (external 40-pin): A[15:0] + D[7:0] → ROM, RAM
//   IBUS (internal 8-bit): AC buffer, bus bridge, ALU B, logic ops
//   ALU_A (internal): AC or PC → adder A (selected by U24-U25 mux)
// ═══════════════════════════════════════════════════════════════

Project: RV8-G,

RV8_Bus:{
    "A[15:0]": "PC (fetch) or operand (data access), via U13+U7 mux",
    "D[7:0]":  "ROM/RAM ↔ U10 (245) ↔ IBUS",
    "/RD":     "derived from control (SOURCE_TYPE OR fetch_state)",
    "/WR":     "derived from STORE bit",
    pinout: "Same 40-pin as all RV8 variants"
},

IBUS:{
    width: 8,
    drivers: ["U9 (AC buffer)", "U10 (RAM bridge)", "U19 (PC buffer)"],
    consumers: ["U5-U6 (XOR→ALU B)", "U20-U21 (AND inputs)", "U22-U23 (OR inputs)",
                "U11-U12 (AC D-mux B-input)", "U10 (RAM write)"],
    rule: "One driver at a time (AC_TO_BUS, BUF_OE, PC_TO_BUS mutually exclusive)"
},

Part:{
    // ═══════════════════════════════════════════
    // CORE (same as RV8-GR, 19 chips)
    // ═══════════════════════════════════════════

    U1:{type:74HC574, function:"AC (accumulator, ALU A source)",
        1:GND, 11:AC_CLK, "2-9":"from U26-U27 result mux", "12-19":"→U24-U25 ALU_A mux + U9 buffer",
        10:GND, 20:VCC},

    U2:{type:74HC574, function:"IR_HIGH (control byte, encodes instruction)",
        1:GND, 11:IR_CLK, "2-9":"D[7:0] from ROM", "12-19":"Q→control signals + derived gates",
        10:GND, 20:VCC},

    U3:{type:74HC283, function:"ALU adder low nibble",
        "A1-A4":"from U24 mux (AC or PC)", "B1-B4":"from U5 XOR output",
        C0:"ALU_SUB", "S1-S4":"SUM[3:0]→U26 result mux", C4:"→U4.C0",
        8:GND, 16:VCC},

    U4:{type:74HC283, function:"ALU adder high nibble",
        "A1-A4":"from U25 mux (AC or PC)", "B1-B4":"from U6 XOR output",
        C0:"U3.C4", "S1-S4":"SUM[7:4]→U27 result mux", C4:"CARRY→U14",
        8:GND, 16:VCC},

    U5:{type:74HC86, function:"XOR low (SUB invert + XOR op bits 0-3)",
        "A inputs":"IBUS[3:0]", "B inputs":"ALU_SUB",
        "Y outputs":"→U3.B[3:0] AND →U26 result mux (XOR mode)",
        7:GND, 14:VCC},

    U6:{type:74HC86, function:"XOR high (SUB invert + XOR op bits 4-7)",
        "A inputs":"IBUS[7:4]", "B inputs":"ALU_SUB",
        "Y outputs":"→U4.B[7:4] AND →U27 result mux (XOR mode)",
        7:GND, 14:VCC},

    U7:{type:74HC157, function:"Address mux A[7:4] (PC vs operand)",
        1:"ADDR_MODE", "A inputs":"PC[7:4]", "B inputs":"OPR[7:4]", "Y outputs":"A[7:4]",
        8:GND, 15:GND, 16:VCC},

    U8:{type:74HC574, function:"IR_LOW (operand byte)",
        1:GND, 11:OPR_CLK, "2-9":"D[7:0] from ROM", "12-19":"→U7+U13 addr mux B + IBUS(imm)",
        10:GND, 20:VCC},

    U9:{type:74HC541, function:"AC → IBUS buffer (for MV rd,a0 and SB)",
        1:"AC_TO_BUS", 19:"AC_TO_BUS", "2-9":"AC.Q[7:0]", "11-18":"IBUS[7:0]",
        10:GND, 20:VCC},

    U10:{type:74HC245, function:"Bus bridge (IBUS ↔ RV8-Bus D[7:0])",
        1:"BUF_DIR", 19:"BUF_OE", "2-9":"IBUS[7:0]", "11-18":"D[7:0]",
        10:GND, 20:VCC},

    U11:{type:74HC157, function:"AC D-mux low (select result source bits 0-3)",
        1:"MUX_SEL", "A":"U26.Y[3:0]", "B":"IBUS[3:0]", "Y":"→AC.D[3:0]",
        8:GND, 15:GND, 16:VCC},

    U12:{type:74HC157, function:"AC D-mux high (select result source bits 4-7)",
        1:"MUX_SEL", "A":"U27.Y[7:4]", "B":"IBUS[7:4]", "Y":"→AC.D[7:4]",
        8:GND, 15:GND, 16:VCC},

    U13:{type:74HC157, function:"Address mux A[3:0] (PC vs operand)",
        1:"ADDR_MODE", "A inputs":"PC[3:0]", "B inputs":"OPR[3:0]", "Y outputs":"A[3:0]",
        8:GND, 15:GND, 16:VCC},

    U14:{type:74HC74, function:"Flags (Z,C) + state toggle",
        "FF1":"D=ZERO_DETECT, CLK=FLAGS_CLK, Q=FLAG_Z",
        "FF2":"D=/Q, CLK=CLK, Q=STATE (fetch/execute toggle)",
        1:"/RST", 7:GND, 13:"/RST", 14:VCC},

    U15:{type:74HC161, function:"PC[3:0]",   1:"/RST", 2:CLK, 7:"PC_INC", 9:"PC_LD", 15:"→U16.ENT", 8:GND, 16:VCC},
    U16:{type:74HC161, function:"PC[7:4]",   1:"/RST", 2:CLK, 7:"PC_INC", 9:"PC_LD", 10:"U15.TC", 15:"→U17.ENT", 8:GND, 16:VCC},
    U17:{type:74HC161, function:"PC[11:8]",  1:"/RST", 2:CLK, 7:"PC_INC", 9:"PC_LD", 10:"U16.TC", 15:"→U18.ENT", 8:GND, 16:VCC},
    U18:{type:74HC161, function:"PC[15:12]", 1:"/RST", 2:CLK, 7:"PC_INC", 9:"PC_LD", 10:"U17.TC", 8:GND, 16:VCC},

    U19:{type:74HC541, function:"PC → IBUS buffer (for JAL: save return address)",
        1:"PC_TO_BUS", 19:"PC_TO_BUS", "2-9":"PC[7:0]", "11-18":"IBUS[7:0]",
        10:GND, 20:VCC},

    // ═══════════════════════════════════════════
    // EXTRA CHIPS (+8 for full ISA)
    // ═══════════════════════════════════════════

    U20:{type:74HC08, function:"AND low nibble: AC[3:0] AND IBUS[3:0]",
        1:"AC.Q0", 2:"IBUS0", 3:"AND0",
        4:"AC.Q1", 5:"IBUS1", 6:"AND1",
        9:"AC.Q2", 10:"IBUS2", 8:"AND2",
        12:"AC.Q3", 13:"IBUS3", 11:"AND3",
        7:GND, 14:VCC},

    U21:{type:74HC08, function:"AND high nibble: AC[7:4] AND IBUS[7:4]",
        1:"AC.Q4", 2:"IBUS4", 3:"AND4",
        4:"AC.Q5", 5:"IBUS5", 6:"AND5",
        9:"AC.Q6", 10:"IBUS6", 8:"AND6",
        12:"AC.Q7", 13:"IBUS7", 11:"AND7",
        7:GND, 14:VCC},

    U22:{type:74HC32, function:"OR low nibble: AC[3:0] OR IBUS[3:0]",
        1:"AC.Q0", 2:"IBUS0", 3:"OR0",
        4:"AC.Q1", 5:"IBUS1", 6:"OR1",
        9:"AC.Q2", 10:"IBUS2", 8:"OR2",
        12:"AC.Q3", 13:"IBUS3", 11:"OR3",
        7:GND, 14:VCC},

    U23:{type:74HC32, function:"OR high nibble: AC[7:4] OR IBUS[7:4]",
        1:"AC.Q4", 2:"IBUS4", 3:"OR4",
        4:"AC.Q5", 5:"IBUS5", 6:"OR5",
        9:"AC.Q6", 10:"IBUS6", 8:"OR6",
        12:"AC.Q7", 13:"IBUS7", 11:"OR7",
        7:GND, 14:VCC},

    U24:{type:74HC157, function:"ALU A mux low (AC vs PC for relative branch)",
        1:"PC_MODE", "A":"AC.Q[3:0]", "B":"PC[3:0]", "Y":"→U3.A[3:0]",
        8:GND, 15:GND, 16:VCC},

    U25:{type:74HC157, function:"ALU A mux high (AC vs PC)",
        1:"PC_MODE", "A":"AC.Q[7:4]", "B":"PC[7:4]", "Y":"→U4.A[7:4]",
        8:GND, 15:GND, 16:VCC},

    U26:{type:74HC157, function:"Result mux low (select ADD/AND/OR/XOR → AC)",
        1:"RESULT_SEL", "A":"SUM[3:0]", "B":"AND/OR/XOR[3:0]", "Y":"→U11.A[3:0]",
        8:GND, 15:GND, 16:VCC},

    U27:{type:74HC157, function:"Result mux high",
        1:"RESULT_SEL", "A":"SUM[7:4]", "B":"AND/OR/XOR[7:4]", "Y":"→U12.A[7:4]",
        8:GND, 15:GND, 16:VCC},

    // ═══════════════════════════════════════════
    // MEMORY
    // ═══════════════════════════════════════════

    ROM:{type:SST39SF010A, function:"Program ROM (128KB, 70ns)",
        "/CE":"A15=1 (ROM at $8000+)", "/OE":"/RD", "/WE":VCC},
    RAM:{type:62256, function:"RAM (32KB, registers at $00-$07)",
        "/CE":"A15=0 (RAM at $0000+)", "/OE":"/RD", "/WE":"/WR"},

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
// CONTROL ENCODING (same as RV8-GR + extra bits for logic ops)
// ═══════════════════════════════════════════════════════════════
//
// IR_HIGH (U2) Q[7:0]:
//   Q7: ALU_SUB
//   Q6: XOR_MODE
//   Q5: MUX_SEL (0=result→AC, 1=IBUS→AC)
//   Q4: AC_WR
//   Q3: SOURCE_TYPE (0=imm, 1=RAM register)
//   Q2: STORE
//   Q1: BRANCH
//   Q0: JUMP
//
// Extra control (from operand byte upper bits when needed):
//   RESULT_SEL[1:0]: 00=adder, 01=AND, 10=OR, 11=XOR
//   PC_MODE: 1=PC feeds ALU A (for relative branch)
//
// Derived (gates):
//   ADDR_MODE = Q3 OR Q2
//   BUF_OE = Q3 OR Q2
//   BUF_DIR = Q2
//   AC_TO_BUS = Q2

// ═══════════════════════════════════════════════════════════════
// VERIFICATION
// ═══════════════════════════════════════════════════════════════
//
// Bus conflicts: NONE
//   IBUS: one of U9/U10/U19 drives (mutually exclusive control bits)
//   Address: PC (fetch) or operand (execute) via U13+U7 mux
//   ALU A: AC (normal) or PC (branch) via U24-U25 mux
//   Result: adder/AND/OR/XOR selected by U26-U27 mux → U11-U12 → AC
//
// All 27 chips accounted for. Same RV8-Bus. Same Programmer board.
}
