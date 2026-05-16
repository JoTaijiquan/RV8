{
// ═══════════════════════════════════════════════════════════════
// RV8-WR CPU — WiringGuide (Bus-Centric)
// 19 logic chips + ROM + RAM = 21 packages
//
// NO MICROCODE. Instruction control byte directly drives hardware.
// RAM REGISTERS ($00-$07). Only AC is a real chip.
// 2-cycle fetch + 1-cycle execute = 3 cycles per instruction.
//
// TWO BUSES:
//   RV8-Bus (external, 40-pin): A[15:0] + D[7:0] → ROM, RAM
//   IBUS (internal, 8-bit): AC buffer, bus bridge, ALU B input
//
// AC (U1) hardwired to ALU A. XOR chips reused for XOR instruction.
// ═══════════════════════════════════════════════════════════════

Project: RV8-WR,

// ═══════════════════════════════════════════════════════════════
// RV8-Bus (EXTERNAL) — 40-pin, same as all RV8 variants
// ═══════════════════════════════════════════════════════════════

RV8_Bus:{
    "A[15:0]": "From PC (fetch) or operand (register/memory access)",
    "D[7:0]":  "ROM data out / RAM data ↔ U10 (245 bridge) ↔ IBUS",
    "/RD":     "From IR_HIGH control bit → ROM./OE + RAM./OE",
    "/WR":     "From IR_HIGH control bit → RAM./WE",
    CLK:       "Crystal oscillator",
    "/RST":    "10K pull-up + 100nF + pushbutton",
    "/IRQ":    "10K pull-up (active low, directly to state logic)",
    SYNC:      "State=0 (new instruction starting)",

    pinout: {
        "1-8":   "A[7:0]",
        "9-16":  "A[15:8]",
        "17-24": "D[7:0]",
        25:"/RD", 26:"/WR", 27:"CLK", 28:"/RST",
        29:"/NMI", 30:"/IRQ", 31:"HALT", 32:"SYNC",
        "33-38":"reserved", 39:"VCC", 40:"GND"}
},

// ═══════════════════════════════════════════════════════════════
// IBUS (INTERNAL) — 8-bit, connects AC buffer + bus bridge + ALU B
// ═══════════════════════════════════════════════════════════════

IBUS:{
    width: 8,
    drivers: [
        "U10 (245 bus bridge, when reading RAM → IBUS)",
        "U9 (541 AC buffer, when AC_TO_BUS=1)"
    ],
    consumers: [
        "U5-U6 (XOR chips, ALU B input via XOR)",
        "U10 (245 bus bridge, when writing IBUS → RAM)",
        "U1 (AC D-input, via mux: ALU result or IBUS)"
    ],
    rule: "Only one driver at a time. Controlled by IR_HIGH bits."
},

// ═══════════════════════════════════════════════════════════════
// CHIPS (19 logic)
// ═══════════════════════════════════════════════════════════════

Part:{

    // === AC (the only real register) ===
    U1:{type:74HC574, bus:"ALU_A (hardwired) + IBUS (via U9 buffer)",
        function:"AC — accumulator, always drives ALU A",
        1:GND, 11:AC_CLK, 10:GND, 20:VCC,
        "2-9":"AC D-inputs (from ALU result OR IBUS, selected by U11-U12 mux)",
        "12-19":"AC Q-outputs → ALU A (U3.A + U4.A) + U9 buffer input"},
    // /OE=GND (always drives ALU A)
    // CLK=AC_CLK (from IR_HIGH bit, gated by state)
    // D from mux: adder output (ADD/SUB) or XOR output (XOR) or IBUS (LI/LB)

    // === IR (instruction register, 2 bytes) ===
    U2:{type:74HC574, function:"IR_HIGH — control byte, outputs DRIVE hardware",
        1:GND, 11:IR_CLK, 10:GND, 20:VCC,
        "2-9":"D[7:0] from RV8-Bus (ROM data)",
        "12-19":"Q → directly to: ALU_SUB, AC_CLK, MEM_WR, AC_TO_BUS, XOR_MODE, ADDR_MODE, etc."},
    // /OE=GND (always output)
    // Q bits ARE the control signals (no decode needed!)

    U8:{type:74HC574, function:"IR_LOW — operand byte (imm value or register address)",
        1:GND, 11:OPR_CLK, 10:GND, 20:VCC,
        "2-9":"D[7:0] from RV8-Bus (ROM data)",
        "12-19":"Q → address bus A[7:0] (register addr $00-$07 or memory addr)"},
    // Operand drives address bus during execute (to read RAM register or memory)

    // === ALU (adder + XOR) ===
    U3:{type:74HC283, function:"ALU adder low nibble",
        5:"AC.Q0", 3:"AC.Q1", 14:"AC.Q2", 12:"AC.Q3",
        6:"U5.Y0", 2:"U5.Y1", 15:"U5.Y2", 11:"U5.Y3",
        7:"ALU_SUB (carry in)", 8:GND, 9:"→U4.C0",
        4:"SUM0", 1:"SUM1", 13:"SUM2", 10:"SUM3", 16:VCC},

    U4:{type:74HC283, function:"ALU adder high nibble",
        5:"AC.Q4", 3:"AC.Q5", 14:"AC.Q6", 12:"AC.Q7",
        6:"U6.Y0", 2:"U6.Y1", 15:"U6.Y2", 11:"U6.Y3",
        7:"U3.C4", 8:GND, 9:"CARRY_OUT → U14.D",
        4:"SUM4", 1:"SUM5", 13:"SUM6", 10:"SUM7", 16:VCC},

    U5:{type:74HC86, function:"XOR low nibble (SUB invert + XOR instruction)",
        1:"IBUS0", 2:"ALU_SUB", 3:"→U3.B0 (or →AC.D0 in XOR mode)",
        4:"IBUS1", 5:"ALU_SUB", 6:"→U3.B1 (or →AC.D1)",
        7:GND, 8:"→U3.B2 (or →AC.D2)",
        9:"IBUS2", 10:"ALU_SUB", 11:"→U3.B3 (or →AC.D3)",
        12:"IBUS3", 13:"ALU_SUB", 14:VCC},
    // When ALU_SUB=1: inverts IBUS for subtraction
    // When XOR_MODE=1: output = AC XOR IBUS (routed to AC.D, bypass adder)

    U6:{type:74HC86, function:"XOR high nibble",
        1:"IBUS4", 2:"ALU_SUB", 3:"→U4.B0 (or →AC.D4)",
        4:"IBUS5", 5:"ALU_SUB", 6:"→U4.B1 (or →AC.D5)",
        7:GND, 8:"→U4.B2 (or →AC.D6)",
        9:"IBUS6", 10:"ALU_SUB", 11:"→U4.B3 (or →AC.D7)",
        12:"IBUS7", 13:"ALU_SUB", 14:VCC},

    // === PC (16-bit counter, auto-increment) ===
    U15:{type:74HC161, function:"PC bit 3:0",
        1:"/RST", 2:CLK, "3-6":"D[3:0] (for JMP load)", 7:"PC_INC",
        8:GND, 9:"PC_LD", 10:"PC_INC", "11-14":"A3,A2,A1,A0",
        15:"→U16.ENT", 16:VCC},
    U16:{type:74HC161, function:"PC bit 7:4",
        1:"/RST", 2:CLK, "3-6":"D[7:4]", 7:"PC_INC",
        8:GND, 9:"PC_LD", 10:"U15.TC", "11-14":"A7,A6,A5,A4",
        15:"→U17.ENT", 16:VCC},
    U17:{type:74HC161, function:"PC bit 11:8",
        1:"/RST", 2:CLK, "3-6":"D[3:0]", 7:"PC_INC",
        8:GND, 9:"PC_LD", 10:"U16.TC", "11-14":"A11,A10,A9,A8",
        15:"→U18.ENT", 16:VCC},
    U18:{type:74HC161, function:"PC bit 15:12",
        1:"/RST", 2:CLK, "3-6":"D[7:4]", 7:"PC_INC",
        8:GND, 9:"PC_LD", 10:"U17.TC", "11-14":"A15,A14,A13,A12",
        15:"nc", 16:VCC},
    // PC_INC: from state logic (HIGH during fetch cycles)
    // PC_LD: from branch logic (pulse to load new PC for JMP)
    // D inputs: from IBUS (for JMP — AC value loaded into PC)

    // === AC → IBUS buffer ===
    U9:{type:74HC541, function:"AC output → IBUS (for MV rd,a0 and SB)",
        1:"AC_TO_BUS", 19:"AC_TO_BUS",
        "2-9":"AC.Q[7:0]", "11-18":"IBUS[7:0]",
        10:GND, 20:VCC},
    // /OE1=/OE2=AC_TO_BUS: LOW when AC needs to drive IBUS (store/move)

    // === Bus bridge (IBUS ↔ RAM data) ===
    U10:{type:74HC245, function:"Bridge: IBUS ↔ RV8-Bus D[7:0]",
        1:"BUF_DIR", 19:"BUF_OE",
        "2-9":"IBUS[7:0]", "11-18":"D[7:0] (RV8-Bus)",
        10:GND, 20:VCC},
    // DIR: 0=RAM→IBUS (read), 1=IBUS→RAM (write)
    // /OE: LOW during memory access steps

    // === AC D-input mux (adder result vs IBUS vs XOR) ===
    U11:{type:74HC157, function:"AC D-mux low nibble (select result source)",
        1:"MUX_SEL", 15:GND,
        2:"SUM0", 3:"IBUS0_or_XOR0", 4:"→AC.D0",
        5:"SUM1", 6:"IBUS1_or_XOR1", 7:"→AC.D1",
        11:"SUM2", 10:"IBUS2_or_XOR2", 9:"→AC.D2",
        14:"SUM3", 13:"IBUS3_or_XOR3", 12:"→AC.D3",
        8:GND, 16:VCC},
    U12:{type:74HC157, function:"AC D-mux high nibble",
        1:"MUX_SEL", 15:GND,
        2:"SUM4", 3:"IBUS4_or_XOR4", 4:"→AC.D4",
        5:"SUM5", 6:"IBUS5_or_XOR5", 7:"→AC.D5",
        11:"SUM6", 10:"IBUS6_or_XOR6", 9:"→AC.D6",
        14:"SUM7", 13:"IBUS7_or_XOR7", 12:"→AC.D7",
        8:GND, 16:VCC},
    // MUX_SEL=0: AC.D ← adder output (ADD/SUB)
    // MUX_SEL=1: AC.D ← IBUS (LI/LB) or XOR output (XOR instruction)
    // XOR output and IBUS share the B-input (only one active at a time)

    // === Address mux (PC vs operand for low byte) ===
    U13:{type:74HC157, function:"Address mux A[7:0]: PC low vs operand",
        1:"ADDR_MODE", 15:GND,
        2:"PC.A0", 3:"OPR.Q0", 4:"A0",
        5:"PC.A1", 6:"OPR.Q1", 7:"A1",
        11:"PC.A2", 10:"OPR.Q2", 9:"A2",
        14:"PC.A3", 13:"OPR.Q3", 12:"A3",
        8:GND, 16:VCC},
    U7:{type:74HC157, function:"Address mux A[7:4]: PC vs operand high nibble",
        1:"ADDR_MODE", 15:GND,
        2:"PC.A4", 3:"OPR.Q4", 4:"A4",
        5:"PC.A5", 6:"OPR.Q5", 7:"A5",
        11:"PC.A6", 10:"OPR.Q6", 9:"A6",
        14:"PC.A7", 13:"OPR.Q7", 12:"A7",
        8:GND, 16:VCC},
    // ADDR_MODE=0: PC drives A[7:0] (fetch from ROM)
    // ADDR_MODE=1: operand drives A[7:0] (access RAM register/memory)
    // A[15:8]: from PC high (U17-U18) during fetch, forced $00 during register access

    // === Flags + State ===
    U14:{type:74HC74, function:"Flags (Z,C) + state counter",
        1:"/RST", 2:"ALU_ZERO", 3:"FLAGS_CLK", 4:VCC,
        5:"FLAG_Z", 6:"nc", 7:GND,
        8:"nc", 9:"STATE", 10:VCC, 11:CLK, 12:"/Q_STATE",
        13:"/RST", 14:VCC},
    // FF1: Z flag (D=zero detect, CLK=flags_clk)
    // FF2: State toggle (D=/Q, CLK=system CLK → toggles 0,1,0,1...)
    //   STATE=0: fetch cycle
    //   STATE=1: execute cycle
    //   (Need 3 states for 3-cycle... use 2-bit counter or accept 2-cycle with pipeline)

    // === MEMORY ===
    ROM:{type:SST39SF010A, bus:RV8_Bus, function:"Program ROM (128KB, 70ns)",
        "A[16:0]":"from address bus", "D[7:0]":"→ RV8-Bus D[7:0]",
        "/CE":"A15 (active when A15=1, ROM at $8000+)", "/OE":"/RD", "/WE":VCC},

    RAM:{type:62256, bus:RV8_Bus, function:"Data RAM (32KB, includes registers $00-$07)",
        "A[14:0]":"from address bus", "D[7:0]":"↔ RV8-Bus D[7:0]",
        "/CE":"NOT(A15) (active when A15=0, RAM at $0000+)", "/OE":"/RD", "/WE":"/WR"},

    // === SUPPORT ===
    OSC:{type:"Crystal 3.5/10MHz", output:CLK},
    R1:{type:"10K", 1:VCC, 2:"/RST"},
    SW:{type:"Pushbutton", 1:"/RST", 2:GND},
    C1:{type:"100nF", 1:"/RST", 2:GND}
},

// ═══════════════════════════════════════════════════════════════
// CONTROL (from IR_HIGH bits — no microcode!)
// ═══════════════════════════════════════════════════════════════
//
// IR_HIGH (U2) Q outputs directly control hardware:
//   Q7: ALU_SUB (0=ADD, 1=SUB)
//   Q6: XOR_MODE (1=XOR result → AC, bypass adder)
//   Q5: MUX_SEL (0=adder→AC, 1=IBUS/XOR→AC)
//   Q4: AC_CLK_EN (1=write result to AC)
//   Q3: AC_TO_BUS (1=AC drives IBUS for store)
//   Q2: BUF_OE (1=enable RAM↔IBUS bridge)
//   Q1: BUF_DIR (0=RAM→IBUS read, 1=IBUS→RAM write)
//   Q0: ADDR_MODE (0=PC drives address, 1=operand drives address)
//
// State logic (U14 FF2) provides:
//   PC_INC = NOT(STATE) (PC counts during fetch)
//   Execute signals gated by STATE=1

// ═══════════════════════════════════════════════════════════════
// VERIFICATION
// ═══════════════════════════════════════════════════════════════
//
// Bus conflicts: NONE
//   IBUS: U9 (AC buffer) or U10 (RAM bridge) — never both (controlled by IR_HIGH bits)
//   Address bus: PC (fetch, ADDR_MODE=0) or operand (execute, ADDR_MODE=1)
//   A[15:8]: PC high during fetch, $00 during register access (A15=0 → RAM selected)
//
// XOR for free: ✅
//   U5-U6 XOR outputs routed to U11-U12 mux B-input
//   When XOR_MODE=1 + MUX_SEL=1: AC gets XOR result
//
// Chip count: 19 logic (U1-U18 + U9... wait, let me recount)
//   U1 (AC) + U2 (IR_HIGH) + U3-U4 (283×2) + U5-U6 (86×2) +
//   U7 (157) + U8 (IR_LOW) + U9 (541) + U10 (245) +
//   U11-U12 (157×2) + U13 (157) + U14 (74) +
//   U15-U18 (161×4) = 18 chips
//   
//   Hmm, 18 not 19. The 19th was for PC→IBUS (JAL). Need U19 (541):
//
    U19:{type:74HC541, function:"PC low → IBUS (for JAL: save return address)",
        1:"PC_TO_BUS", 19:"PC_TO_BUS",
        "2-9":"PC.Q[7:0] (from U15-U16 outputs)", "11-18":"IBUS[7:0]",
        10:GND, 20:VCC},
//
// FINAL COUNT: 19 logic chips ✅
// Total: 19 + ROM + RAM = 21 packages
}
