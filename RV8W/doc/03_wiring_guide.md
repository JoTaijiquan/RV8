{
// ═══════════════════════════════════════════════════════════════
// RV8-W CPU — WiringGuide
// 27 logic chips + ROM + RAM = 29 packages
// = RV8-WR (19 chips) + 8 extra chips for full ISA
// ═══════════════════════════════════════════════════════════════

Project: RV8-W,

// RV8-W = RV8-WR base (19 chips) + these additions:

Extra_chips:{
    // === AND operation (8-bit) ===
    U20:{type:74HC08, function:"AND low nibble (AC[3:0] AND IBUS[3:0])",
        1:"AC.Q0", 2:"IBUS0", 3:"AND_R0",
        4:"AC.Q1", 5:"IBUS1", 6:"AND_R1",
        7:GND, 8:"AND_R2", 9:"AC.Q2", 10:"IBUS2",
        11:"AND_R3", 12:"AC.Q3", 13:"IBUS3", 14:VCC},

    U21:{type:74HC08, function:"AND high nibble (AC[7:4] AND IBUS[7:4])",
        1:"AC.Q4", 2:"IBUS4", 3:"AND_R4",
        4:"AC.Q5", 5:"IBUS5", 6:"AND_R5",
        7:GND, 8:"AND_R6", 9:"AC.Q6", 10:"IBUS6",
        11:"AND_R7", 12:"AC.Q7", 13:"IBUS7", 14:VCC},

    // === OR operation (8-bit) ===
    U22:{type:74HC32, function:"OR low nibble (AC[3:0] OR IBUS[3:0])",
        1:"AC.Q0", 2:"IBUS0", 3:"OR_R0",
        4:"AC.Q1", 5:"IBUS1", 6:"OR_R1",
        7:GND, 8:"OR_R2", 9:"AC.Q2", 10:"IBUS2",
        11:"OR_R3", 12:"AC.Q3", 13:"IBUS3", 14:VCC},

    U23:{type:74HC32, function:"OR high nibble (AC[7:4] OR IBUS[7:4])",
        1:"AC.Q4", 2:"IBUS4", 3:"OR_R4",
        4:"AC.Q5", 5:"IBUS5", 6:"OR_R5",
        7:GND, 8:"OR_R6", 9:"AC.Q6", 10:"IBUS6",
        11:"OR_R7", 12:"AC.Q7", 13:"IBUS7", 14:VCC},

    // === ALU A mux (AC vs PC for relative branch) ===
    U24:{type:74HC157, function:"ALU A mux low (AC[3:0] vs PC[3:0])",
        1:"PC_MODE", 2:"AC.Q0", 3:"PC.A0", 4:"→U3.A1",
        5:"AC.Q1", 6:"PC.A1", 7:"→U3.A2",
        8:GND, 9:"→U3.A3", 10:"PC.A2", 11:"AC.Q2",
        12:"→U3.A4", 13:"PC.A3", 14:"AC.Q3", 15:GND, 16:VCC},

    U25:{type:74HC157, function:"ALU A mux high (AC[7:4] vs PC[7:4])",
        1:"PC_MODE", 2:"AC.Q4", 3:"PC.A4", 4:"→U4.A1",
        5:"AC.Q5", 6:"PC.A5", 7:"→U4.A2",
        8:GND, 9:"→U4.A3", 10:"PC.A6", 11:"AC.Q6",
        12:"→U4.A4", 13:"PC.A7", 14:"AC.Q7", 15:GND, 16:VCC},
    // PC_MODE=0: AC drives ALU A (normal)
    // PC_MODE=1: PC drives ALU A (for relative branch: PC+offset)

    // === Result mux expansion (select ADD/SUB/AND/OR/XOR) ===
    U26:{type:74HC157, function:"Result mux low (select which result → AC)",
        1:"RESULT_SEL0", 2:"ADDER_S0", 3:"AND_R0 or OR_R0", 4:"→U11.B_input",
        // Selects between adder output and logic output
        // Combined with U11-U12 existing mux for final AC.D selection
        8:GND, 15:GND, 16:VCC},

    U27:{type:74HC157, function:"Result mux high",
        8:GND, 15:GND, 16:VCC},
    // Same pattern for bits 4-7

    // === Zero detect (for BEQ/BNE with register compare) ===
    // Uses spare gates from U22-U23 (OR gates cascade for zero detect)
    // OR all result bits → invert → Z flag
},

// Control byte for RV8-W adds 2 more bits (from operand or extra latch):
//   PC_MODE: select PC as ALU A input (for relative branch)
//   RESULT_SEL[1:0]: select result source (adder/AND/OR/XOR)
//
// Total control: 8 bits (IR_HIGH) + 2 bits (from operand field) = 10 bits effective

// CHIP COUNT:
//   RV8-WR base: 19 chips
//   + U20-U21 (08×2): AND operation = +2
//   + U22-U23 (32×2): OR operation = +2
//   + U24-U25 (157×2): ALU A mux (PC for branch) = +2
//   + U26-U27 (157×2): Result mux (select AND/OR/XOR/ADD) = +2
//   Total: 19 + 8 = 27 logic chips ✅
}
