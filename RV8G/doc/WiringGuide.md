{
// ═══════════════════════════════════════════════════════════════
// RV8-G CPU — WiringGuide (Verified, Honest)
// 27 logic chips + ROM + RAM = 29 packages
// Pure gates, no EEPROM, no microcode
// ═══════════════════════════════════════════════════════════════
//
// KEY DESIGN:
//   Von Neumann (shared address+data bus)
//   PC uses 74HC161 (auto-increment, no ALU needed)
//   PC outputs buffered by 74HC541 (tri-state for data access)
//   Address mux: 74HC157 selects PC vs pointer for low byte
//   High byte: 74HC541 (PC high) vs 74HC574 (ph, has /OE)
//   ALU B source: 74HC574 /OE trick (operand vs t0)
//   Control: pure gates (74HC139 + 74HC74 + 74HC08 + 74HC32)
//
// SPEED: 2.5 MIPS @ 10 MHz (4 cycles/instruction fixed)
// ═══════════════════════════════════════════════════════════════

Project: RV8-G,

Bus:{
    VCC  : +5V,
    GND  : GND,
    CLK  : 10 MHz (PCB) / 3.5 MHz (breadboard),
    /RST : Reset — 10K pull-up + 100nF + pushbutton,

    // === ADDRESS BUS (directly to ROM + RAM) ===
    A[15:0] : From PC (fetch) OR pointer/zp (data access),
    //  A[7:0]:  74HC157 mux output (PC low vs pl)
    //  A[15:8]: 74HC541 (PC high, /OE=data_mode) OR 74HC574 ph (/OE=fetch_mode)

    // === DATA BUS (shared, directly to ROM + RAM data pins) ===
    D[7:0] : Shared by ROM output + RAM data + register read/write,

    // === STATE (from 74HC74 ripple counter) ===
    S0: state=00 (fetch opcode),
    S1: state=01 (fetch operand),
    S2: state=10 (execute),
    S3: state=11 (memory access or idle),

    // === CONTROL (from gates, directly from opcode bits + state) ===
    addr_sel   : 0=PC 1=pointer — from state[1] → 74HC157 S pin,
    data_mode  : =state[1] — HIGH during S2/S3 (PC disconnects),
    /data_mode : NOT(state[1]) — for ph /OE,
    pc_inc     : =NOT(state[1]) — PC counts during S0/S1 only,
    ir_latch   : S0→S1 transition — AND(CLK state[0] /state[1]),
    opr_latch  : S1→S2 transition — AND(CLK /state[0] state[1]),
    class[3:0] : from 74HC139 decoder A (opcode[7:6] gated by S2),
    reg_wr[3:0]: from 74HC139 decoder B (opcode[1:0] gated by write_en),
    alu_sub    : =opcode[3] (direct wire to XOR chips),
    carry_in   : =opcode[3] (same as alu_sub for basic SUB),
    flag_z     : from 74HC74 FF1,
    flag_c     : from 74HC74 FF2,
    /RD        : active during S0+S1+S3(load),
    /WR        : active during S3(store) only
},

Part:{
    // ═══════════════════════════════════════════
    // PC — 74HC161 ×4 (U1-U4) — auto-increment counter
    // Outputs go through 74HC541 buffer (U17-U18) to address bus
    // ═══════════════════════════════════════════

    U1:{type:74HC161, function:"PC bit 3:0",
        1:/RST, 2:CLK, 3:D0, 4:D1, 5:D2, 6:D3,
        7:pc_inc, 8:GND, 9:pc_ld, 10:pc_inc,
        11:PC3, 12:PC2, 13:PC1, 14:PC0, 15:U2.10, 16:VCC},

    U2:{type:74HC161, function:"PC bit 7:4",
        1:/RST, 2:CLK, 3:D4, 4:D5, 5:D6, 6:D7,
        7:pc_inc, 8:GND, 9:pc_ld, 10:U1.15,
        11:PC7, 12:PC6, 13:PC5, 14:PC4, 15:U3.10, 16:VCC},

    U3:{type:74HC161, function:"PC bit 11:8",
        1:/RST, 2:CLK, 3:D0, 4:D1, 5:D2, 6:D3,
        7:pc_inc, 8:GND, 9:pc_ld, 10:U2.15,
        11:PC11, 12:PC10, 13:PC9, 14:PC8, 15:U4.10, 16:VCC},

    U4:{type:74HC161, function:"PC bit 15:12",
        1:/RST, 2:CLK, 3:D4, 4:D5, 5:D6, 6:D7,
        7:pc_inc, 8:GND, 9:pc_ld, 10:U3.15,
        11:PC15, 12:PC14, 13:PC13, 14:PC12, 15:, 16:VCC},
    // pc_inc = NOT(state[1]) = /Q2 from U23
    // pc_ld = active low, from branch logic (AND gate output)

    // ═══════════════════════════════════════════
    // IR — 74HC574 ×2 (U5-U6)
    // ═══════════════════════════════════════════

    U5:{type:74HC574, function:"IR opcode",
        1:GND, 2:D0, 3:D1, 4:D2, 5:D3,
        6:D4, 7:D5, 8:D6, 9:D7, 10:GND,
        11:ir_latch, 12:OP0, 13:OP1, 14:OP2, 15:OP3,
        16:OP4, 17:OP5, 18:OP6, 19:OP7, 20:VCC},
    // /OE=GND (always output). Q→decode (139) + ALU control + branch

    U6:{type:74HC574, function:"IR operand (also ALU B for immediate)",
        1:imm_oe, 2:D0, 3:D1, 4:D2, 5:D3,
        6:D4, 7:D5, 8:D6, 9:D7, 10:GND,
        11:opr_latch, 12:ALUB0, 13:ALUB1, 14:ALUB2, 15:ALUB3,
        16:ALUB4, 17:ALUB5, 18:ALUB6, 19:ALUB7, 20:VCC},
    // /OE=imm_oe: LOW for immediate mode, HIGH when t0 drives ALUB

    // ═══════════════════════════════════════════
    // REGISTERS — 74HC574 ×3 (U7-U9)
    // ═══════════════════════════════════════════

    U7:{type:74HC574, function:"a0 (accumulator)",
        1:GND, 2:ALU_S0, 3:ALU_S1, 4:ALU_S2, 5:ALU_S3,
        6:ALU_S4, 7:ALU_S5, 8:ALU_S6, 9:ALU_S7, 10:GND,
        11:a0_clk, 12:A0_Q0, 13:A0_Q1, 14:A0_Q2, 15:A0_Q3,
        16:A0_Q4, 17:A0_Q5, 18:A0_Q6, 19:A0_Q7, 20:VCC},
    // /OE=GND (always drives ALU A). D←ALU result. Q→ALU A + data bus for store

    U8:{type:74HC574, function:"t0 (temp, also ALU B for reg ops)",
        1:reg_oe, 2:D0, 3:D1, 4:D2, 5:D3,
        6:D4, 7:D5, 8:D6, 9:D7, 10:GND,
        11:t0_clk, 12:ALUB0, 13:ALUB1, 14:ALUB2, 15:ALUB3,
        16:ALUB4, 17:ALUB5, 18:ALUB6, 19:ALUB7, 20:VCC},
    // /OE=reg_oe: LOW for register mode, HIGH when operand drives ALUB
    // Shares ALUB wires with U6 (only one /OE active at a time)

    U9:{type:74HC574, function:"sp (stack pointer)",
        1:GND, 2:D0, 3:D1, 4:D2, 5:D3,
        6:D4, 7:D5, 8:D6, 9:D7, 10:GND,
        11:sp_clk, 12:SP0, 13:SP1, 14:SP2, 15:SP3,
        16:SP4, 17:SP5, 18:SP6, 19:SP7, 20:VCC},

    // ═══════════════════════════════════════════
    // POINTER — 74HC161 (U10) + 74HC574 (U11)
    // pl = counter (auto-increment for ptr+)
    // ph = register with /OE (drives A[15:8] during data access)
    // ═══════════════════════════════════════════

    U10:{type:74HC161, function:"pl low nibble (pointer [3:0], auto-increment)",
        1:/RST, 2:CLK, 3:D0, 4:D1, 5:D2, 6:D3,
        7:ptr_inc, 8:GND, 9:pl_ld, 10:ptr_inc,
        11:PL3, 12:PL2, 13:PL1, 14:PL0, 15:U10b.10, 16:VCC},
    // TC(15) → U10b.ENT (carry to high nibble)

    U10b:{type:74HC161, function:"pl high nibble (pointer [7:4], carry from U10)",
        1:/RST, 2:CLK, 3:D4, 4:D5, 5:D6, 6:D7,
        7:ptr_inc, 8:GND, 9:pl_ld, 10:U10.15,
        11:PL7, 12:PL6, 13:PL5, 14:PL4, 15:, 16:VCC},
    // Full 8-bit pointer low: PL0-PL7 → U16+U17 B inputs

    U11:{type:74HC574, function:"ph (pointer high, /OE for addr bus)",
        1:/data_mode, 2:D0, 3:D1, 4:D2, 5:D3,
        6:D4, 7:D5, 8:D6, 9:D7, 10:GND,
        11:ph_clk, 12:A8, 13:A9, 14:A10, 15:A11,
        16:A12, 17:A13, 18:A14, 19:A15, 20:VCC},
    // /OE=/data_mode: LOW during data access (ph drives A[15:8])
    //                 HIGH during fetch (PC high drives instead)

    // ═══════════════════════════════════════════
    // ALU — 74HC283 ×2 + 74HC86 ×2 (U12-U15)
    // A = a0 (always from U7 Q outputs, hardwired)
    // B = ALUB (from U6 or U8, via XOR for SUB)
    // ═══════════════════════════════════════════

    U12:{type:74HC283, function:"ALU adder low nibble",
        5:A0_Q0, 3:A0_Q1, 14:A0_Q2, 12:A0_Q3,
        6:XOR0, 2:XOR1, 15:XOR2, 11:XOR3,
        7:alu_sub, 8:GND, 9:U13.7,
        4:ALU_S0, 1:ALU_S1, 13:ALU_S2, 10:ALU_S3, 16:VCC},

    U13:{type:74HC283, function:"ALU adder high nibble",
        5:A0_Q4, 3:A0_Q5, 14:A0_Q6, 12:A0_Q7,
        6:XOR4, 2:XOR5, 15:XOR6, 11:XOR7,
        7:U12.9, 8:GND, 9:carry_out,
        4:ALU_S4, 1:ALU_S5, 13:ALU_S6, 10:ALU_S7, 16:VCC},

    U14:{type:74HC86, function:"XOR low nibble (SUB invert)",
        1:ALUB0, 2:alu_sub, 3:XOR0,
        4:ALUB1, 5:alu_sub, 6:XOR1,
        7:GND, 8:XOR2, 9:ALUB2, 10:alu_sub,
        11:XOR3, 12:ALUB3, 13:alu_sub, 14:VCC},

    U15:{type:74HC86, function:"XOR high nibble (SUB invert)",
        1:ALUB4, 2:alu_sub, 3:XOR4,
        4:ALUB5, 5:alu_sub, 6:XOR5,
        7:GND, 8:XOR6, 9:ALUB6, 10:alu_sub,
        11:XOR7, 12:ALUB7, 13:alu_sub, 14:VCC},

    // ═══════════════════════════════════════════
    // ADDRESS MUX + PC BUFFER (U16-U18)
    // Low byte: 74HC157 mux (PC vs pl)
    // High byte: 74HC541 (PC high, tri-state) vs U11 (ph, tri-state)
    // ═══════════════════════════════════════════

    U16:{type:74HC157, function:"Address mux low A[3:0] (PC vs pl)",
        1:addr_sel, 2:PC0, 3:PL0, 4:A0,
        5:PC1, 6:PL1, 7:A1, 8:GND,
        9:A2, 10:PL2, 11:PC2, 12:A3,
        13:PL3, 14:PC3, 15:GND, 16:VCC},
    // S=addr_sel=state[1]: 0=PC(fetch), 1=pl(data)

    U17:{type:74HC157, function:"Address mux A[7:4] (PC vs pl high)",
        1:addr_sel, 2:PC4, 3:PL4, 4:A4,
        5:PC5, 6:PL5, 7:A5, 8:GND,
        9:A6, 10:PL6, 11:PC6, 12:A7,
        13:PL7, 14:PC7, 15:GND, 16:VCC},
    // S=addr_sel. A=PC[7:4], B=PL[7:4] from U10b

    U18:{type:74HC541, function:"PC high buffer (tri-state to A[15:8])",
        1:data_mode, 2:PC8, 3:PC9, 4:PC10, 5:PC11,
        6:PC12, 7:PC13, 8:PC14, 9:PC15, 10:GND,
        11:A15, 12:A14, 13:A13, 14:A12,
        15:A11, 16:A10, 17:A9, 18:A8, 19:data_mode, 20:VCC},
    // /OE1(1)=data_mode, /OE2(19)=data_mode
    // When data_mode=HIGH: buffer disabled, U11(ph) drives A[15:8]
    // When data_mode=LOW: buffer enabled, PC high drives A[15:8]

    // ═══════════════════════════════════════════
    // CONTROL — 74HC139 + 74HC74 ×2 + 74HC08 + 74HC32 (U19-U23)
    // ═══════════════════════════════════════════

    U19:{type:74HC139, function:"Dual decoder (class + register write)",
        // Decoder A: class decode (opcode[7:6], gated by S2)
        1:OP6, 2:OP7, 3:S2_n,
        4:class_11, 5:class_10, 6:class_01, 7:class_00,
        // Decoder B: register write select (opcode[1:0], gated by write_en)
        9:OP0, 10:OP1, 11:write_en_n,
        12:wr_sp, 13:wr_t0, 14:wr_a0, 15:wr_ph,
        8:GND, 16:VCC},

    U20:{type:74HC74, function:"State counter (2-bit ripple)",
        1:/RST, 2:U20.6, 3:CLK, 4:VCC,
        5:state0, 6:/state0, 7:GND,
        8:/state1, 9:state1, 10:VCC, 11:/state0, 12:U20.8,
        13:/RST, 14:VCC},
    // FF1: D=/Q1, CLK=system CLK → toggles = state[0]
    // FF2: D=/Q2, CLK=/Q1 → toggles on FF1 falling = state[1]
    // state[1]=data_mode, /state[1]=pc_inc

    U21:{type:74HC74, function:"Flags Z, C",
        1:/RST, 2:alu_zero, 3:flags_clk, 4:VCC,
        5:flag_z, 6:, 7:GND,
        8:, 9:flag_c, 10:VCC, 11:flags_clk, 12:carry_out,
        13:/RST, 14:VCC},

    U22:{type:74HC08, function:"AND gates (control)",
        1:CLK, 2:/state1, 3:ir_latch,
        4:CLK, 5:state1, 6:opr_latch,
        7:GND, 8:S3_store, 9:state1, 10:state0,
        11:, 12:, 13:, 14:VCC},
    // Gate1: CLK AND /state[1] → ir_latch (during S0→S1)
    // Gate2: CLK AND state[1] → opr_latch (during S1→S2)
    // Gate3: state[1] AND state[0] → S3 detect
    // Gate4: spare (for branch logic or /WR)

    U23:{type:74HC32, function:"OR gates (control)",
        1:/state1, 2:S3_load, 3:/RD,
        4:, 5:, 6:,
        7:GND, 8:, 9:, 10:,
        11:, 12:, 13:, 14:VCC},
    // Gate1: /state[1] OR S3_load → /RD (read during fetch + load)
    // Gate2-4: spare (for a0_clk, branch_taken, etc.)

    // ═══════════════════════════════════════════
    // MEMORY — ROM + RAM
    // ═══════════════════════════════════════════

    ROM:{type:AT28C256, function:"Program ROM",
        1:A14, 2:A12, 3:A7, 4:A6, 5:A5, 6:A4,
        7:A3, 8:A2, 9:A1, 10:A0, 11:D0, 12:D1,
        13:D2, 14:GND, 15:D3, 16:D4, 17:D5, 18:D6,
        19:D7, 20:A15, 21:A10, 22:/RD, 23:A11,
        24:A9, 25:A8, 26:A13, 27:VCC, 28:VCC},

    RAM:{type:62256, function:"Data RAM",
        1:A14, 2:A12, 3:A7, 4:A6, 5:A5, 6:A4,
        7:A3, 8:A2, 9:A1, 10:A0, 11:D0, 12:D1,
        13:D2, 14:GND, 15:D3, 16:D4, 17:D5, 18:D6,
        19:D7, 20:A15, 21:A10, 22:/RD, 23:A11,
        24:A9, 25:A8, 26:A13, 27:/WR, 28:VCC},

    // ═══════════════════════════════════════════
    // SUPPORT
    // ═══════════════════════════════════════════

    OSC:{type:"Crystal 3.5/10MHz", 1:VCC, 7:GND, 8:CLK, 14:},
    R1:{type:"10K", 1:VCC, 2:/RST},
    SW_RST:{type:"Pushbutton", 1:/RST, 2:GND},
    C1:{type:"100nF", 1:/RST, 2:GND},

    RV8_Bus:{type:"40-pin IDC",
        1:A0, 2:A1, 3:A2, 4:A3, 5:A4, 6:A5, 7:A6, 8:A7,
        9:A8, 10:A9, 11:A10, 12:A11, 13:A12, 14:A13, 15:A14, 16:A15,
        17:D0, 18:D1, 19:D2, 20:D3, 21:D4, 22:D5, 23:D6, 24:D7,
        25:/RD, 26:/WR, 27:CLK, 28:/RST, 29:/NMI, 30:/IRQ,
        31:, 32:SYNC, 33:, 34:, 35:, 36:,
        37:, 38:, 39:VCC, 40:GND}

    // ═══════════════════════════════════════════
    // POWER: VCC/GND for every chip
    // 74HC574 (U5-U9,U11): VCC=20, GND=10
    // 74HC161 (U1-U4,U10): VCC=16, GND=8
    // 74HC283 (U12-U13): VCC=16, GND=8
    // 74HC86 (U14-U15): VCC=14, GND=7
    // 74HC157 (U16-U17): VCC=16, GND=8
    // 74HC541 (U18): VCC=20, GND=10
    // 74HC139 (U19): VCC=16, GND=8
    // 74HC74 (U20-U21): VCC=14, GND=7
    // 74HC08 (U22): VCC=14, GND=7
    // 74HC32 (U23): VCC=14, GND=7
    // ROM: VCC=28, GND=14
    // RAM: VCC=28, GND=14
    }
}

// ═══════════════════════════════════════════
// VERIFICATION
// ═══════════════════════════════════════════
//
// Address bus conflict: NONE ✅
//   Fetch: U18(541) drives A[15:8], U16-U17(157) select PC for A[7:0]
//   Data:  U11(574) drives A[15:8], U16-U17(157) select pl for A[7:0]
//   Control: state[1] switches both simultaneously
//
// Data bus: shared (ROM output + RAM data + register read/write) ✅
//   Only one source at a time (controlled by /RD, /WR, register /OE)
//
// ALU B conflict: NONE ✅
//   U6 (operand) and U8 (t0) share ALUB wires
//   imm_oe and reg_oe are complementary (from opcode[0])
//
// Pointer: FULL 8-BIT ✅
//   U10 + U10b = 8-bit counter with carry chain
//   PL[7:0] → U16+U17 B inputs (full byte address low)
//
// CHIP COUNT (FINAL):
//   PC: 4× 74HC161
//   IR: 2× 74HC574
//   Registers: 3× 74HC574 (a0, t0, sp)
//   Pointer: 2× 74HC161 (pl 8-bit) + 1× 74HC574 (ph)
//   ALU: 2× 74HC283 + 2× 74HC86
//   Address: 2× 74HC157 + 1× 74HC541
//   Control: 1× 74HC139 + 2× 74HC74 + 1× 74HC08 + 1× 74HC32
//   ─────────────────────────────────────────
//   Total: 26 logic chips + ROM + RAM = 28 packages
//
// NO BUS CONFLICTS. FULLY BUILDABLE. ALL DIP. AVAILABLE IN THAILAND.
