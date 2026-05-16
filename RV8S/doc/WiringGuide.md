{
// ═══════════════════════════════════════════════════════════════
// RV8-S CPU — WiringGuide
// 19 logic chips + ROM + RAM = 21 packages
// Serial ALU, shift registers, Flash microcode
// Same RISC-V ISA as RV8 (just slower execution)
// ═══════════════════════════════════════════════════════════════
//
// ARCHITECTURE:
//   Registers are 74HC595 shift registers (serial I/O + parallel out)
//   ALU is 1-bit (XOR + AND + carry FF) — processes 8 bits in 8 clocks
//   Fetch is parallel (PC drives ROM, data latches normally)
//   Execute is serial (shift register → ALU → shift register)
//   Microcode Flash sequences serial/parallel operations
//
// SPEED: 1.0 MIPS @ 10 MHz (~10 clocks per instruction)
// ═══════════════════════════════════════════════════════════════

Project: RV8-S,

Bus:{
    VCC  : +5V,
    GND  : GND,
    CLK  : 10 MHz (PCB) / 3.5 MHz (breadboard),
    /RST : Reset — 10K pull-up + 100nF + pushbutton,

    // === ADDRESS BUS (parallel, from PC counters) ===
    A[15:0] : From PC (U14-U17) during fetch, from register parallel out during data access,

    // === DATA BUS (parallel, 8-bit, ROM/RAM interface) ===
    D[7:0] : ROM data out / RAM data in-out,

    // === SERIAL BUS (1-bit, internal ALU chain) ===
    SER_A  : Serial data from source register QH' → ALU input A,
    SER_B  : Serial data from second register QH' → ALU input B (via XOR),
    SER_R  : Serial ALU result → destination register SER input,
    CARRY  : Carry FF output → ALU carry input (U11.Q),

    // === CONTROL (from Flash U16) ===
    SRCLK  : Shift clock → all 595 registers (shift one bit),
    RCLK   : Latch clock → 595 parallel outputs update,
    REG_SEL[2:0] : Which register connects to serial chain (from Flash),
    ALU_SUB: SUB mode → XOR inverts B input,
    IR_CLK : Latch opcode from D[7:0] → U9,
    OPR_CLK: Latch operand from D[7:0] → U10,
    PC_INC : Increment PC,
    MEM_RD : /RD signal → ROM/RAM,
    MEM_WR : /WR signal → RAM,
    SYNC   : Instruction boundary pulse → bus pin 32
},

Part:{
    // ═══════════════════════════════════════════
    // REGISTERS r0-r7 — 74HC595 ×8 (U1-U8)
    // Shift registers: serial in/out + parallel output
    // Serial chain for ALU, parallel out for address/data bus
    // ═══════════════════════════════════════════

    U1:{type:74HC595, function:"r0 (zero — SER tied LOW)",
        8:GND, 9:SER_R, 10:/RST, 11:SRCLK, 12:RCLK,
        13:GND, 14:GND, 15:Q0, 1:Q1, 2:Q2, 3:Q3, 4:Q4, 5:Q5, 6:Q6, 7:Q7, 16:VCC},
    // pin 8(GND), pin 16(VCC)
    // pin 14(SER)=GND (always shifts in 0 → r0 stays zero)
    // pin 11(SRCLK)=shift clock, pin 12(RCLK)=latch to parallel
    // pin 9(QH')=serial out (last bit shifted out) → to serial mux
    // pin 10(/SRCLR)=/RST
    // pin 13(/OE)=GND (parallel outputs always active)
    // pin 15,1-7(QA-QH)=parallel output → address/data bus when selected

    U2:{type:74HC595, function:"r1 (a0 / return value)",
        8:GND, 9:SER_OUT_R1, 10:/RST, 11:SRCLK, 12:RCLK,
        13:GND, 14:SER_R, 15:Q0, 1:Q1, 2:Q2, 3:Q3, 4:Q4, 5:Q5, 6:Q6, 7:Q7, 16:VCC},
    // pin 14(SER)=SER_R (ALU result shifts in)
    // pin 9(QH')=serial out → SER_A (to ALU as operand A)

    U3:{type:74HC595, function:"r2 (a1)",
        8:GND, 9:SER_OUT_R2, 10:/RST, 11:SRCLK, 12:RCLK,
        13:GND, 14:SER_R, 15:Q0, 1:Q1, 2:Q2, 3:Q3, 4:Q4, 5:Q5, 6:Q6, 7:Q7, 16:VCC},

    U4:{type:74HC595, function:"r3 (t0)",
        8:GND, 9:SER_OUT_R3, 10:/RST, 11:SRCLK, 12:RCLK,
        13:GND, 14:SER_R, 15:Q0, 1:Q1, 2:Q2, 3:Q3, 4:Q4, 5:Q5, 6:Q6, 7:Q7, 16:VCC},

    U5:{type:74HC595, function:"r4 (t1)",
        8:GND, 9:SER_OUT_R4, 10:/RST, 11:SRCLK, 12:RCLK,
        13:GND, 14:SER_R, 15:Q0, 1:Q1, 2:Q2, 3:Q3, 4:Q4, 5:Q5, 6:Q6, 7:Q7, 16:VCC},

    U6:{type:74HC595, function:"r5 (s0)",
        8:GND, 9:SER_OUT_R5, 10:/RST, 11:SRCLK, 12:RCLK,
        13:GND, 14:SER_R, 15:Q0, 1:Q1, 2:Q2, 3:Q3, 4:Q4, 5:Q5, 6:Q6, 7:Q7, 16:VCC},

    U7:{type:74HC595, function:"r6 (s1 / page)",
        8:GND, 9:SER_OUT_R6, 10:/RST, 11:SRCLK, 12:RCLK,
        13:GND, 14:SER_R, 15:Q0, 1:Q1, 2:Q2, 3:Q3, 4:Q4, 5:Q5, 6:Q6, 7:Q7, 16:VCC},

    U8:{type:74HC595, function:"r7 (ra / sp)",
        8:GND, 9:SER_OUT_R7, 10:/RST, 11:SRCLK, 12:RCLK,
        13:GND, 14:SER_R, 15:Q0, 1:Q1, 2:Q2, 3:Q3, 4:Q4, 5:Q5, 6:Q6, 7:Q7, 16:VCC},

    // All registers: same wiring pattern
    // SER(14) = serial input (ALU result or data load)
    // QH'(9) = serial output (to ALU via mux)
    // SRCLK(11) = shift clock (from microcode)
    // RCLK(12) = parallel latch (update outputs after shift complete)
    // QA-QH = parallel outputs (to address bus or data bus)

    // ═══════════════════════════════════════════
    // IR — 74HC574 ×2 (U9-U10) — parallel latch (standard)
    // ═══════════════════════════════════════════

    U9:{type:74HC574, function:"IR opcode (parallel latch from ROM)",
        1:GND, 2:D0, 3:D1, 4:D2, 5:D3,
        6:D4, 7:D5, 8:D6, 9:D7, 10:GND,
        11:IR_CLK, 12:OP0, 13:OP1, 14:OP2, 15:OP3,
        16:OP4, 17:OP5, 18:OP6, 19:OP7, 20:VCC},
    // /OE=GND, CLK=IR_CLK, D←D[7:0] from ROM, Q→Flash address

    U10:{type:74HC574, function:"IR operand (parallel latch from ROM)",
        1:GND, 2:D0, 3:D1, 4:D2, 5:D3,
        6:D4, 7:D5, 8:D6, 9:D7, 10:GND,
        11:OPR_CLK, 12:OPR0, 13:OPR1, 14:OPR2, 15:OPR3,
        16:OPR4, 17:OPR5, 18:OPR6, 19:OPR7, 20:VCC},
    // Q[7:5]=rs field → register select, Q[4:0]=immediate/offset

    // ═══════════════════════════════════════════
    // ALU — 1-bit serial (U11 carry + U12 XOR + U13 AND)
    // Full adder: SUM = A⊕B⊕Cin, Cout = (A∧B)∨(Cin∧(A⊕B))
    // ═══════════════════════════════════════════

    U11:{type:74HC74, function:"Carry FF + state",
        1:/RST, 2:CARRY_NEXT, 3:SRCLK, 4:VCC,
        5:CARRY, 6:, 7:GND,
        8:, 9:STATE, 10:VCC, 11:CLK, 12:STATE_NEXT,
        13:/RST, 14:VCC},
    // FF1: Carry flip-flop. D=CARRY_NEXT, CLK=SRCLK, Q=CARRY
    // FF2: State/step counter bit (for fetch/execute sequencing)

    U12:{type:74HC86, function:"XOR gates (ALU sum + SUB invert)",
        1:SER_A, 2:SER_B_INV, 3:A_XOR_B,
        4:A_XOR_B, 5:CARRY, 6:SER_R,
        7:GND,
        8:, 9:SER_B, 10:ALU_SUB, 11:SER_B_INV,
        12:, 13:, 14:VCC},
    // Gate 1: SER_A XOR SER_B_INV → A_XOR_B (partial sum)
    // Gate 2: A_XOR_B XOR CARRY → SER_R (final sum bit → dest register)
    // Gate 3: SER_B XOR ALU_SUB → SER_B_INV (invert B for subtract)
    // Gate 4: spare

    U13:{type:74HC08, function:"AND gates (carry generate)",
        1:SER_A, 2:SER_B_INV, 3:AB,
        4:CARRY, 5:A_XOR_B, 6:C_AND_AXB,
        7:GND,
        8:CARRY_NEXT, 9:AB, 10:C_AND_AXB,
        11:, 12:, 13:, 14:VCC},
    // Gate 1: A AND B_inv → AB
    // Gate 2: CARRY AND A_XOR_B → C_AND_AXB
    // Gate 3: AB OR C_AND_AXB → CARRY_NEXT (actually need OR... use gate 3 of U12 spare? or...)
    // PROBLEM: need OR for carry. Use 74HC32? Or trick: AB + C*(A⊕B) can use NAND trick.
    // FIX: Use spare XOR as OR approximation, or accept: need 1× 74HC32 (+1 chip = 20 logic)

    // Actually: Cout = (A∧B) | (Cin∧(A⊕B))
    // Need 1 OR gate. Use spare from... nowhere. Need 74HC32.
    // OR: use De Morgan: Cout = NOT(NOT(AB) AND NOT(C_AND_AXB)) — needs NAND... also not available.
    // ACCEPT: +1× 74HC32 for carry OR. Total = 20 logic chips.

    // ═══════════════════════════════════════════
    // PC — 74HC161 ×4 (U14-U17) — parallel counter (standard)
    // ═══════════════════════════════════════════

    U14:{type:74HC161, function:"PC bit 3:0",
        1:/RST, 2:CLK, 3:D0, 4:D1, 5:D2, 6:D3,
        7:PC_INC, 8:GND, 9:PC_LD, 10:PC_INC,
        11:A3, 12:A2, 13:A1, 14:A0, 15:U15.10, 16:VCC},

    U15:{type:74HC161, function:"PC bit 7:4",
        1:/RST, 2:CLK, 3:D4, 4:D5, 5:D6, 6:D7,
        7:PC_INC, 8:GND, 9:PC_LD, 10:U14.15,
        11:A7, 12:A6, 13:A5, 14:A4, 15:U16.10, 16:VCC},

    U16:{type:74HC161, function:"PC bit 11:8",
        1:/RST, 2:CLK, 3:D0, 4:D1, 5:D2, 6:D3,
        7:PC_INC, 8:GND, 9:PC_LD, 10:U15.15,
        11:A11, 12:A10, 13:A9, 14:A8, 15:U17.10, 16:VCC},

    U17:{type:74HC161, function:"PC bit 15:12",
        1:/RST, 2:CLK, 3:D4, 4:D5, 5:D6, 6:D7,
        7:PC_INC, 8:GND, 9:PC_LD, 10:U16.15,
        11:A15, 12:A14, 13:A13, 14:A12, 15:, 16:VCC},

    // ═══════════════════════════════════════════
    // REGISTER SELECT — 74HC138 (U18)
    // Selects which register's serial output connects to ALU
    // ═══════════════════════════════════════════

    U18:{type:74HC138, function:"Register serial select (which QH' → SER_B)",
        1:REG_SEL0, 2:REG_SEL1, 3:REG_SEL2, 4:GND,
        5:GND, 6:VCC, 7:/Y7, 8:GND,
        9:/Y6, 10:/Y5, 11:/Y4, 12:/Y3,
        13:/Y2, 14:/Y1, 15:/Y0, 16:VCC},
    // Outputs enable which register's QH' connects to SER_B
    // (via tri-state or mux — may need 74HC151 8:1 mux for serial select)
    // ISSUE: 138 gives active-low enables, but serial out is always active on 595.
    // FIX: Use 74HC151 (8:1 mux) instead — selects one of 8 serial outputs.
    // Replace U18 with 74HC151. Same chip count.

    // ═══════════════════════════════════════════
    // MICROCODE — SST39SF010A (U19)
    // ═══════════════════════════════════════════

    U19:{type:SST39SF010A, function:"Microcode Flash (sequences serial operations)",
        // Address: {step[3:0], opcode[7:0], flags[1:0]} = 14 bits
        // Data: 8 control outputs
        //   D0=SRCLK_EN (enable shift clock to registers)
        //   D1=ALU_SUB
        //   D2=REG_SEL bit (shared with step counter for mux)
        //   D3=PC_INC
        //   D4=IR_CLK
        //   D5=OPR_CLK
        //   D6=MEM_RD
        //   D7=SYNC/STEP_RST
        10:OP0, 9:OP1, 8:OP2, 7:OP3, 6:OP4, 5:OP5, 4:OP6, 3:OP7,
        25:STEP0, 24:STEP1, 21:STEP2, 23:STEP3,
        26:FLAG_Z, 1:FLAG_C,
        2:GND, 14:GND, 20:GND, 22:GND, 30:GND,
        27:VCC, 28:VCC, 31:VCC, 32:VCC,
        11:CTRL0, 12:CTRL1, 13:CTRL2, 15:CTRL3,
        16:CTRL4, 17:CTRL5, 18:CTRL6, 19:CTRL7},

    // ═══════════════════════════════════════════
    // MEMORY + SUPPORT
    // ═══════════════════════════════════════════

    ROM:{type:AT28C256, function:"Program ROM",
        1:A14, 2:A12, 3:A7, 4:A6, 5:A5, 6:A4,
        7:A3, 8:A2, 9:A1, 10:A0, 11:D0, 12:D1,
        13:D2, 14:GND, 15:D3, 16:D4, 17:D5, 18:D6,
        19:D7, 20:A15, 21:A10, 22:MEM_RD, 23:A11,
        24:A9, 25:A8, 26:A13, 27:VCC, 28:VCC},

    RAM:{type:62256, function:"Data RAM",
        1:A14, 2:A12, 3:A7, 4:A6, 5:A5, 6:A4,
        7:A3, 8:A2, 9:A1, 10:A0, 11:D0, 12:D1,
        13:D2, 14:GND, 15:D3, 16:D4, 17:D5, 18:D6,
        19:D7, 20:A15, 21:A10, 22:MEM_RD, 23:A11,
        24:A9, 25:A8, 26:A13, 27:MEM_WR, 28:VCC},

    OSC:{type:"Crystal 3.5/10MHz", 1:VCC, 7:GND, 8:CLK, 14:},
    R1:{type:"10K", 1:VCC, 2:/RST},
    SW_RST:{type:"Pushbutton", 1:/RST, 2:GND},
    C1:{type:"100nF", 1:/RST, 2:GND},

    RV8_Bus:{type:"40-pin IDC",
        1:A0, 2:A1, 3:A2, 4:A3, 5:A4, 6:A5, 7:A6, 8:A7,
        9:A8, 10:A9, 11:A10, 12:A11, 13:A12, 14:A13, 15:A14, 16:A15,
        17:D0, 18:D1, 19:D2, 20:D3, 21:D4, 22:D5, 23:D6, 24:D7,
        25:MEM_RD, 26:MEM_WR, 27:CLK, 28:/RST, 29:/NMI, 30:/IRQ,
        31:HALT, 32:SYNC, 33:, 34:, 35:, 36:,
        37:, 38:, 39:VCC, 40:GND}

    // ═══════════════════════════════════════════
    // POWER
    // 74HC595 (U1-U8): VCC=16, GND=8
    // 74HC574 (U9-U10): VCC=20, GND=10
    // 74HC74 (U11): VCC=14, GND=7
    // 74HC86 (U12): VCC=14, GND=7
    // 74HC08 (U13): VCC=14, GND=7
    // 74HC161 (U14-U17): VCC=16, GND=8
    // 74HC138/151 (U18): VCC=16, GND=8
    // SST39SF010A (U19): VCC=32, GND=16
    // ROM: VCC=28, GND=14
    // RAM: VCC=28, GND=14
    // ═══════════════════════════════════════════
    }
}

// ═══════════════════════════════════════════
// VERIFICATION
// ═══════════════════════════════════════════
//
// ISSUE FOUND: Carry generation needs OR gate (not available in 74HC08)
//   Fix: +1× 74HC32 (OR gate for carry) → 20 logic chips total
//   Or: use wired-OR with diodes (hacky but works)
//
// ISSUE: Register serial select needs 8:1 mux (74HC151) not 138
//   138 gives active-low enables but 595 QH' is always driving
//   Fix: replace U18 (138) with 74HC151 (8:1 mux) — same chip count
//
// ISSUE: Loading parallel data INTO 595 registers (for LB instruction)
//   595 has NO parallel load! Can only shift in serially.
//   For LB: must shift 8 bits from data bus into register (8 clocks)
//   This is handled by microcode (8 shift steps with data bus bit selected)
//   But: need a way to select which D[x] bit feeds SER input...
//   Fix: use 74HC151 (8:1 mux) to select D[bit_n] → SER input, shift 8 times
//   This REUSES U18 (already a 151) with different address per shift step
//
// HONEST CHIP COUNT: 20 logic + ROM + RAM = 22 packages
//   (added 74HC32 for carry OR gate)
//
// COMPATIBLE WITH RV8-BUS: ✅ (same 40-pin, same signals)
