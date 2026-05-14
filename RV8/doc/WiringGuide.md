{
// ═══════════════════════════════════════════════════════════════
// RV8 CPU — Full Function Wiring Guide
// 26 chips + control EEPROM (realistic full decode)
// ═══════════════════════════════════════════════════════════════
//
// NOTE: The original 26-chip design assumed control decode fits in
// U22 (74HC08) + U23 (74HC32). In reality, the full 17-state FSM
// with 68-instruction decode needs a CONTROL EEPROM (AT28C16 or
// similar) to generate all control signals from {state, opcode}.
// This is the REALISTIC full-function wiring.
//
// Alternative: use ~4 more gate chips instead of EEPROM.
// ═══════════════════════════════════════════════════════════════

Project: RV8,

Bus:{
    // === POWER ===
    VCC  : +5V,
    GND  : GND,

    // === RESET + CLOCK ===
    /RST : Reset active low — R1(10K) pull-up + SW_RST to GND + C7(100nF) debounce,
    CLK  : Clock 3.5MHz — OSC output,

    // === ADDRESS BUS (active during memory access, accent from address mux U16-U17) ===
    A0: U16.4,  A1: U16.7,  A2: U16.9,  A3: U16.12,
    A4: U17.4,  A5: U17.7,  A6: U17.9,  A7: U17.12,
    A8: (from high-byte mux or hardwired page),
    A9:, A10:, A11:, A12:, A13:, A14:, A15:,

    // === DATA BUS (directly from U19 74HC245 B-side) ===
    D0: U19.18, D1: U19.17, D2: U19.16, D3: U19.15,
    D4: U19.14, D5: U19.13, D6: U19.12, D7: U19.11,

    // === MEMORY CONTROL (accent from control EEPROM) ===
    /RD : control_eeprom.D0 — memory read strobe → ROM.22 + RAM.22,
    /WR : control_eeprom.D1 — memory write strobe → RAM.27,

    // === STATE (from state counter U_SC) ===
    S0: state_counter.Q0,
    S1: state_counter.Q1,
    S2: state_counter.Q2,
    S3: state_counter.Q3,
    S4: state_counter.Q4,

    // === CONTROL SIGNALS (from control EEPROM outputs accent accent) ===
    pc_inc   : ctrl.D2 — increment PC → U1-U4 ENP+ENT,
    pc_ld    : ctrl.D3 — load PC (branch/jump) → U1-U4 /LD,
    ir0_clk  : ctrl.D4 — latch opcode → U5.11,
    ir1_clk  : ctrl.D5 — latch operand → U6.11,
    reg_we   : ctrl.D6 — register write enable,
    mem_rd   : ctrl.D0 — same as /RD,
    mem_wr   : ctrl.D1 — same as /WR,
    alu_op0  : ctrl.D7 — ALU operation bit 0,
    alu_op1  : ctrl2.D0 — ALU operation bit 1,
    alu_op2  : ctrl2.D1 — ALU operation bit 2,
    alu_op3  : ctrl2.D2 — ALU operation bit 3,
    addr_sel0: ctrl2.D3 — address mux select bit 0 → U16.1 + U17.1,
    addr_sel1: ctrl2.D4 — address mux select bit 1,
    wr_sel0  : ctrl2.D5 — register write select bit 0,
    wr_sel1  : ctrl2.D6 — register write select bit 1,
    wr_sel2  : ctrl2.D7 — register write select bit 2,
    sub_mode : derived from alu_op — XOR invert → U15.2/5/10/13,
    carry_in : derived from alu_op + flag_c → U13.7,
    flags_we : from control — latch flags → U20.3 + U20.11 + U21.3,
    sp_inc   : from control — stack pointer +1,
    sp_dec   : from control — stack pointer -1,
    ptr_inc  : from control — pointer auto-increment → U11.7/10 + U12.7,
    bus_dir  : from control — U19.1 (HIGH=A→B read, LOW=B→A write),
    bus_oe   : from control — U19.19 (LOW=enabled),

    // === FLAGS (from U20 + U21) ===
    flag_z   : U20.5 (Q1) — zero flag,
    flag_c   : U20.9 (Q2) — carry flag,
    flag_n   : U21.5 (Q1) — negative flag,
    flag_ie  : U21.9 (Q2) — interrupt enable,
    carry_out: U14.9 (C4) — ALU carry output → U20.12 (D2),
    alu_zero : NOR of all ALU result bits → U20.2 (D1),
    alu_sign : ALU result bit 7 = U12.10 (S4) → U21.2 (D1),

    // === DECODE (from U24 address decode) ===
    /RAM_CE : from U23 gate (OR of /Y0-/Y3) → RAM.20,
    /ROM_CE : from U23 gate (OR of /Y6-/Y7) → ROM.20,
    /IO_CE  : U24.11 (/Y4) directly → RV8-Bus pin 33,

    // === EXTERNAL BUS CONNECTOR ===
    SYNC : instruction start pulse → bus pin 32,
    HALT : CPU halted → bus pin 31,
    /NMI : interrupt input ← bus pin 29 (10K pull-up),
    /IRQ : interrupt input ← bus pin 30 (10K pull-up)
},

Part:{
    // ═══════════════════════════════════════════
    // PROGRAM COUNTER — 74HC161 ×4 (U1-U4)
    // Cascaded 4-bit counters = 16-bit PC
    // Directly drives address mux "A" inputs
    // ═══════════════════════════════════════════

    U1:{type:74HC161, function:"PC bit 3:0",
        1:/RST, 2:CLK, 3:D0, 4:D1,
        5:D2, 6:D3, 7:pc_inc, 8:GND,
        9:pc_ld, 10:pc_inc, 11:U16.14, 12:U16.11,
        13:U16.6, 14:U16.2, 15:U2.10, 16:VCC},
    // pin 1(/CLR)=/RST, pin 2(CLK)=CLK
    // pin 3-6(D0-D3)=data bus D0-D3 (for PC load on branch/jump)
    // pin 7(ENP)=pc_inc, pin 10(ENT)=pc_inc
    // pin 9(/LD)=pc_ld (active low, loads D when LOW)
    // pin 14(QA)→U16.2(1A), pin 13(QB)→U16.6(2A), pin 12(QC)→U16.11(3A), pin 11(QD)→U16.14(4A)
    // pin 15(TC)→U2.10(ENT) carry chain

    U2:{type:74HC161, function:"PC bit 7:4",
        1:/RST, 2:CLK, 3:D4, 4:D5,
        5:D6, 6:D7, 7:pc_inc, 8:GND,
        9:pc_ld, 10:U1.15, 11:U17.14, 12:U17.11,
        13:U17.6, 14:U17.2, 15:U3.10, 16:VCC},

    U3:{type:74HC161, function:"PC bit 11:8",
        1:/RST, 2:CLK, 3:D0, 4:D1,
        5:D2, 6:D3, 7:pc_inc, 8:GND,
        9:pc_ld, 10:U2.15, 11:ROM.23, 12:ROM.21,
        13:ROM.24, 14:ROM.25, 15:U4.10, 16:VCC},
    // Q outputs go directly to ROM A8-A11 (high address, no mux needed for upper bits)

    U4:{type:74HC161, function:"PC bit 15:12",
        1:/RST, 2:CLK, 3:D4, 4:D5,
        5:D6, 6:D7, 7:pc_inc, 8:GND,
        9:pc_ld, 10:U3.15, 11:ROM.23, 12:ROM.1,
        13:ROM.26, 14:ROM.2, 15:, 16:VCC},
    // Q outputs → ROM A12-A14 + A15 to address decode U24

    // ═══════════════════════════════════════════
    // INSTRUCTION REGISTER — 74HC574 ×2 (U5-U6)
    // Latches opcode (F0) and operand (F1) from data bus
    // ═══════════════════════════════════════════

    U5:{type:74HC574, function:"IR opcode",
        1:GND, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:ir0_clk, 12:ctrl_eeprom.A0,
        13:ctrl_eeprom.A1, 14:ctrl_eeprom.A2, 15:ctrl_eeprom.A3,
        16:ctrl_eeprom.A4, 17:U18.1, 18:U18.2, 19:U18.3, 20:VCC},
    // pin 1(/OE)=GND (always output)
    // pin 11(CLK)=ir0_clk (from control, active during F0)
    // pin 12-16(Q0-Q4)=opcode[4:0] → control EEPROM address A0-A4
    // pin 17-19(Q5-Q7)=opcode[7:5] → U18 A,B,C (unit decode)

    U6:{type:74HC574, function:"IR operand",
        1:GND, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:ir1_clk, 12:U15.1,
        13:U15.4, 14:U15.9, 15:U15.12, 16:U13.5,
        17:U13.3, 18:U13.14, 19:U13.12, 20:VCC},
    // pin 1(/OE)=GND
    // pin 11(CLK)=ir1_clk (from control, active during F1)
    // pin 12-15(Q0-Q3) → U15 XOR inputs (ALU B low nibble via XOR)
    // pin 16-19(Q4-Q7) → U13/U14 B inputs directly (ALU B high nibble)
    //   (NOTE: high nibble also needs XOR for SUB — needs 2nd 74HC86 or
    //    route through spare gates. Simplified here: direct for ADD, XOR for SUB)
    // ALL Q0-Q7 also connect to: address mux B inputs (for immediate addressing)
    //   and PC data inputs (for branch offset loading)

    // ═══════════════════════════════════════════
    // REGISTERS — 74HC574 ×4 (U7-U10)
    // ═══════════════════════════════════════════

    U7:{type:74HC574, function:"a0 (accumulator)",
        1:GND, 2:U11.4, 3:U11.1, 4:U11.13,
        5:U11.10, 6:U12.4, 7:U12.1, 8:U12.13,
        9:U12.10, 10:GND, 11:a0_clk, 12:U13.5,
        13:U13.3, 14:U13.14, 15:U13.12, 16:U14.5,
        17:U14.3, 18:U14.14, 19:U14.12, 20:VCC},
    // pin 1(/OE)=GND
    // pin 2-9(D0-D7) ← ALU result: U11.S1,S2,S3,S4 + U12.S1,S2,S3,S4
    // pin 11(CLK) = a0_clk (from control, when reg_we + wr_sel=a0)
    // pin 12-19(Q0-Q7) → ALU A inputs: U13.A1-A4 + U14.A1-A4

    U8:{type:74HC574, function:"t0 (temporary)",
        1:GND, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:t0_clk, 12:,
        13:, 14:, 15:, 16:,
        17:, 18:, 19:, 20:VCC},
    // pin 2-9(D) ← data bus (for LI t0, POP t0, LB→t0)
    // pin 11(CLK) = t0_clk (from control)
    // pin 12-19(Q) → ALU B input (when ALU source = register)
    //               → data bus (when PUSH t0 or MOV from t0)

    U9:{type:74HC574, function:"sp (stack pointer)",
        1:GND, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:sp_clk, 12:,
        13:, 14:, 15:, 16:,
        17:, 18:, 19:, 20:VCC},
    // pin 2-9(D) ← data bus or sp+1/sp-1 (from ALU)
    // pin 11(CLK) = sp_clk (from control)
    // pin 12-19(Q) → address mux (stack address low byte)
    //               → ALU A (for sp+imm calculation)

    U10:{type:74HC574, function:"pg (page register)",
        1:GND, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:pg_clk, 12:,
        13:, 14:, 15:, 16:,
        17:, 18:, 19:, 20:VCC},
    // pin 2-9(D) ← data bus (for LI pg)
    // pin 11(CLK) = pg_clk (from control)
    // pin 12-19(Q) → address mux high byte (for pg:imm addressing)

    // ═══════════════════════════════════════════
    // POINTER — 74HC161 ×2 (U11-U12)
    // 8-bit pointer with auto-increment (ptr+)
    // ═══════════════════════════════════════════

    U11:{type:74HC161, function:"pl (pointer low)",
        1:/RST, 2:CLK, 3:D0, 4:D1,
        5:D2, 6:D3, 7:ptr_inc, 8:GND,
        9:pl_ld, 10:ptr_inc, 11:U16.13, 12:U16.10,
        13:U16.5, 14:U16.3, 15:U12.10, 16:VCC},
    // pin 3-6(D) ← data bus (for LI pl)
    // pin 7(ENP)=ptr_inc, pin 10(ENT)=ptr_inc
    // pin 9(/LD)=pl_ld (load from data bus)
    // pin 14(QA)→U16.3(1B), pin 13(QB)→U16.5(2B)
    // pin 12(QC)→U16.10(3B), pin 11(QD)→U16.13(4B)
    // pin 15(TC)→U12.10(ENT) carry to high byte

    U12:{type:74HC161, function:"ph (pointer high)",
        1:/RST, 2:CLK, 3:D4, 4:D5,
        5:D6, 6:D7, 7:ptr_inc, 8:GND,
        9:ph_ld, 10:U11.15, 11:U17.13, 12:U17.10,
        13:U17.5, 14:U17.3, 15:, 16:VCC},
    // pin 14(QA)→U17.3(1B), pin 13(QB)→U17.5(2B)
    // pin 12(QC)→U17.10(3B), pin 11(QD)→U17.13(4B)

    // ═══════════════════════════════════════════
    // ALU — 74HC283 ×2 + 74HC86 (U13-U15)
    // 8-bit adder + XOR for SUB inversion
    // ═══════════════════════════════════════════

    U13:{type:74HC283, function:"ALU adder low nibble",
        1:, 2:, 3:U7.13, 4:,
        5:U7.12, 6:U15.3, 7:carry_in, 8:GND,
        9:U14.7, 10:, 11:U15.11, 12:U7.15,
        13:, 14:U7.14, 15:U15.8, 16:VCC},
    // pin 5(A1)=a0 bit0 (U7.12), pin 3(A2)=a0 bit1 (U7.13)
    // pin 14(A3)=a0 bit2 (U7.14), pin 12(A4)=a0 bit3 (U7.15)
    // pin 6(B1)=U15.3(1Y), pin 2(B2)=U15.6(2Y)
    // pin 15(B3)=U15.8(3Y), pin 11(B4)=U15.11(4Y)
    // pin 7(C0)=carry_in (0=ADD, 1=SUB)
    // pin 4(S1)→a0 D0 (U7.2), pin 1(S2)→a0 D1 (U7.3)
    // pin 13(S3)→a0 D2 (U7.4), pin 10(S4)→a0 D3 (U7.5)
    // pin 9(C4)→U14.7(C0) carry to high nibble

    U14:{type:74HC283, function:"ALU adder high nibble",
        1:, 2:, 3:U7.17, 4:,
        5:U7.16, 6:, 7:U13.9, 8:GND,
        9:carry_out, 10:, 11:, 12:U7.19,
        13:, 14:U7.18, 15:, 16:VCC},
    // pin 5(A1)=a0 bit4 (U7.16), pin 3(A2)=a0 bit5 (U7.17)
    // pin 14(A3)=a0 bit6 (U7.18), pin 12(A4)=a0 bit7 (U7.19)
    // pin 6(B1)=operand bit4 XOR sub_mode
    // pin 2(B2)=operand bit5 XOR sub_mode
    // pin 15(B3)=operand bit6 XOR sub_mode
    // pin 11(B4)=operand bit7 XOR sub_mode
    // pin 7(C0)=U13.9(C4) carry from low nibble
    // pin 4(S1)→a0 D4 (U7.6), pin 1(S2)→a0 D5 (U7.7)
    // pin 13(S3)→a0 D6 (U7.8), pin 10(S4)→a0 D7 (U7.9)
    // pin 9(C4)=carry_out → U20.12(D2) flag_c input

    U15:{type:74HC86, function:"XOR — SUB invert (low nibble)",
        1:U6.12, 2:sub_mode, 3:U13.6, 4:U6.13,
        5:sub_mode, 6:U13.2, 7:GND, 8:U13.15,
        9:U6.14, 10:sub_mode, 11:U13.11, 12:U6.15,
        13:sub_mode, 14:VCC},
    // Gate 1: pin1(A)=operand bit0, pin2(B)=sub_mode → pin3(Y)→U13.6(B1)
    // Gate 2: pin4(A)=operand bit1, pin5(B)=sub_mode → pin6(Y)→U13.2(B2)
    // Gate 3: pin9(A)=operand bit2, pin10(B)=sub_mode → pin8(Y)→U13.15(B3)
    // Gate 4: pin12(A)=operand bit3, pin13(B)=sub_mode → pin11(Y)→U13.11(B4)
    // NOTE: High nibble (bits 4-7) needs a 2nd 74HC86 (U15B) or route differently

    // ═══════════════════════════════════════════
    // ADDRESS MUX — 74HC157 ×2 (U16-U17)
    // Selects PC (S=0) or Pointer (S=1) → address bus
    // ═══════════════════════════════════════════

    U16:{type:74HC157, function:"Address mux low nibble (A3:A0)",
        1:addr_sel0, 2:U1.14, 3:U11.14, 4:A0,
        5:U1.13, 6:U11.13, 7:A1, 8:GND,
        9:A2, 10:U11.12, 11:U1.12, 12:A3,
        13:U11.11, 14:U1.11, 15:GND, 16:VCC},
    // pin 1(S)=addr_sel0: 0=select A inputs (PC), 1=select B inputs (pointer)
    // pin 15(/E)=GND (always enabled)
    // 1A=U1.14(PC0), 1B=U11.14(pl0) → 1Y=A0 (pin 4)
    // 2A=U1.13(PC1), 2B=U11.13(pl1) → 2Y=A1 (pin 7)
    // 3A=U1.12(PC2), 3B=U11.12(pl2) → 3Y=A2 (pin 9)
    // 4A=U1.11(PC3), 4B=U11.11(pl3) → 4Y=A3 (pin 12)

    U17:{type:74HC157, function:"Address mux high nibble (A7:A4)",
        1:addr_sel0, 2:U2.14, 3:U12.14, 4:A4,
        5:U2.13, 6:U12.13, 7:A5, 8:GND,
        9:A6, 10:U12.12, 11:U2.12, 12:A7,
        13:U12.11, 14:U2.11, 15:GND, 16:VCC},
    // Same pattern: A inputs from PC (U2), B inputs from pointer (U12)
    // Outputs → A4-A7 → ROM/RAM address pins

    // ═══════════════════════════════════════════
    // INSTRUCTION DECODE — 74HC138 (U18)
    // Decodes opcode[7:5] into 8 unit-select lines
    // ═══════════════════════════════════════════

    U18:{type:74HC138, function:"Instruction unit decode",
        1:U5.17, 2:U5.18, 3:U5.19, 4:GND,
        5:GND, 6:VCC, 7:, 8:GND,
        9:, 10:, 11:, 12:,
        13:, 14:, 15:, 16:VCC},
    // pin 1(A)=U5.17(opcode bit5), pin 2(B)=U5.18(bit6), pin 3(C)=U5.19(bit7)
    // pin 4(/G2A)=GND, pin 5(/G2B)=GND, pin 6(G1)=VCC (always enabled)
    // pin 15(/Y0)=unit0 active, pin 14(/Y1)=unit1, ..., pin 7(/Y7)=unit7
    // These feed into control EEPROM or additional decode gates

    // ═══════════════════════════════════════════
    // BUS BUFFER — 74HC245 (U19)
    // Bidirectional buffer between internal data bus and external
    // ═══════════════════════════════════════════

    U19:{type:74HC245, function:"Data bus buffer",
        1:bus_dir, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:D7_ext, 12:D6_ext,
        13:D5_ext, 14:D4_ext, 15:D3_ext, 16:D2_ext,
        17:D1_ext, 18:D0_ext, 19:bus_oe, 20:VCC},
    // pin 1(DIR)=bus_dir: HIGH=A→B(CPU reads), LOW=B→A(CPU writes)
    // pin 19(/OE)=bus_oe: LOW=enabled (during memory access)
    // A side (pin 2-9) = internal data bus
    // B side (pin 11-18) = external bus (ROM/RAM/IO data pins)

    // ═══════════════════════════════════════════
    // FLAGS — 74HC74 ×2 (U20-U21)
    // ═══════════════════════════════════════════

    U20:{type:74HC74, function:"Flags: Z and C",
        1:/RST, 2:alu_zero, 3:flags_we, 4:VCC,
        5:flag_z, 6:, 7:GND, 8:,
        9:flag_c, 10:VCC, 11:flags_we, 12:U14.9,
        13:/RST, 14:VCC},
    // FF1: pin2(D)=alu_zero, pin3(CLK)=flags_we, pin5(Q)=flag_z
    // FF2: pin12(D)=carry_out(U14.9), pin11(CLK)=flags_we, pin9(Q)=flag_c
    // pin1,13(/CLR)=/RST, pin4,10(/PRE)=VCC

    U21:{type:74HC74, function:"Flags: N and IE",
        1:/RST, 2:U12.10, 3:flags_we, 4:VCC,
        5:flag_n, 6:, 7:GND, 8:,
        9:flag_ie, 10:VCC, 11:ie_clk, 12:ie_data,
        13:/RST, 14:VCC},
    // FF1: pin2(D)=alu_sign(ALU result bit7), pin3(CLK)=flags_we, pin5(Q)=flag_n
    // FF2: pin12(D)=ie_data(from EI/DI instruction), pin11(CLK)=ie_clk, pin9(Q)=flag_ie
    // pin1,13(/CLR)=/RST

    // ═══════════════════════════════════════════
    // CONTROL LOGIC — 74HC08 + 74HC32 (U22-U23)
    // Basic gates for chip-enable combining
    // ═══════════════════════════════════════════

    U22:{type:74HC08, function:"AND gates",
        1:, 2:, 3:, 4:,
        5:, 6:, 7:GND, 8:,
        9:, 10:, 11:, 12:,
        13:, 14:VCC},
    // Available for: NMI edge detect, skip gating, misc control
    // Specific assignments depend on control EEPROM vs discrete decode

    U23:{type:74HC32, function:"OR gates (chip enable combining)",
        1:U24.15, 2:U24.14, 3:, 4:U23.3,
        5:U24.13, 6:, 7:GND, 8:,
        9:U24.9, 10:U24.7, 11:/ROM_CE, 12:U23.6,
        13:U24.12, 14:VCC},
    // Gate 1: pin1=U24./Y0, pin2=U24./Y1 → pin3 (partial RAM CE)
    // Gate 2: pin4=gate1 out, pin5=U24./Y2 → pin6 (more RAM CE)
    //   (NOTE: need 4-input OR for /Y0-/Y3. Use 2 gates cascaded)
    //   Final /RAM_CE = gate2.out OR U24./Y3 → needs gate3
    // Gate 3: pin9=U24./Y6, pin10=U24./Y7 → pin11=/ROM_CE → ROM.20
    // Gate 4: pin12=gate2 out, pin13=U24./Y3 → pin8=/RAM_CE → RAM.20
    //   (NOTE: this uses all 4 gates for address decode combining)

    // ═══════════════════════════════════════════
    // ADDRESS DECODE — 74HC138 (U24)
    // Decodes A[15:13] into 8 memory regions
    // ═══════════════════════════════════════════

    U24:{type:74HC138, function:"Address decode",
        1:A13, 2:A14, 3:A15, 4:GND,
        5:GND, 6:VCC, 7:/Y7, 8:GND,
        9:/Y6, 10:/Y5, 11:/Y4, 12:/Y3,
        13:/Y2, 14:/Y1, 15:/Y0, 16:VCC},
    // pin 1(A)=A13, pin 2(B)=A14, pin 3(C)=A15
    // pin 6(G1)=VCC, pin 4(/G2A)=GND, pin 5(/G2B)=GND
    // /Y0(pin15): $0000-$1FFF RAM ─┐
    // /Y1(pin14): $2000-$3FFF RAM  ├→ OR (U23) → /RAM_CE → RAM.20
    // /Y2(pin13): $4000-$5FFF RAM  │
    // /Y3(pin12): $6000-$7FFF RAM ─┘
    // /Y4(pin11): $8000-$9FFF I/O → /IO_CE → bus pin 33
    // /Y5(pin10): $A000-$BFFF (unused)
    // /Y6(pin 9): $C000-$DFFF ROM ─┬→ OR (U23) → /ROM_CE → ROM.20
    // /Y7(pin 7): $E000-$FFFF ROM ─┘

    // ═══════════════════════════════════════════
    // CONTROL EEPROM — AT28C16 (optional, replaces complex gate decode)
    // Generates all control signals from {state[4:0], opcode[4:0]}
    // ═══════════════════════════════════════════

    CTRL:{type:AT28C16, function:"Control signal generator (microcode)",
        // Address inputs: A0-A4 = opcode[4:0] (from U5 pins 12-16)
        //                 A5-A9 = state[4:0] (from state counter)
        //                 A10   = flag_z or branch condition
        // Data outputs: D0-D7 = control signals
        //   D0=/RD, D1=/WR, D2=pc_inc, D3=pc_ld,
        //   D4=ir0_clk, D5=ir1_clk, D6=reg_we, D7=alu_op0
        // NOTE: May need 2nd EEPROM for remaining signals (alu_op1-3, wr_sel, addr_sel)
        },

    // ═══════════════════════════════════════════
    // ROM — AT28C256 (32KB program storage)
    // ═══════════════════════════════════════════

    ROM:{type:AT28C256, function:"Program ROM ($C000-$FFFF)",
        1:A14, 2:A12, 3:A7, 4:A6,
        5:A5, 6:A4, 7:A3, 8:A2,
        9:A1, 10:A0, 11:D0, 12:D1,
        13:D2, 14:GND, 15:D3, 16:D4,
        17:D5, 18:D6, 19:D7, 20:/ROM_CE,
        21:A10, 22:/RD, 23:A11, 24:A9,
        25:A8, 26:A13, 27:VCC, 28:VCC},
    // pin 20(/CE)=/ROM_CE from U23
    // pin 22(/OE)=/RD from control
    // pin 27(/WE)=VCC (never write during operation)

    // ═══════════════════════════════════════════
    // RAM — 62256 (32KB data storage)
    // ═══════════════════════════════════════════

    RAM:{type:62256, function:"Data RAM ($0000-$7FFF)",
        1:A14, 2:A12, 3:A7, 4:A6,
        5:A5, 6:A4, 7:A3, 8:A2,
        9:A1, 10:A0, 11:D0, 12:D1,
        13:D2, 14:GND, 15:D3, 16:D4,
        17:D5, 18:D6, 19:D7, 20:/RAM_CE,
        21:A10, 22:/RD, 23:A11, 24:A9,
        25:A8, 26:A13, 27:/WR, 28:VCC},
    // pin 20(/CE)=/RAM_CE from U23
    // pin 22(/OE)=/RD from control
    // pin 27(/WE)=/WR from control

    // ═══════════════════════════════════════════
    // CLOCK + RESET + PASSIVES
    // ═══════════════════════════════════════════

    OSC:{type:"Crystal Oscillator 3.5MHz (4-pin DIP)", function:"Clock source",
        1:, 7:GND, 8:CLK, 14:VCC},

    R1:{type:"10K", function:"Reset pull-up", 1:VCC, 2:/RST},
    SW_RST:{type:"Pushbutton NO", function:"Reset button", 1:/RST, 2:GND},
    C1:{type:"100nF", function:"Reset debounce", 1:/RST, 2:GND},
    C2:{type:"100nF", function:"Decoupling OSC", 1:VCC, 2:GND},
    C3:{type:"100nF", function:"Decoupling ROM", 1:VCC, 2:GND},
    C4:{type:"100nF", function:"Decoupling RAM", 1:VCC, 2:GND},
    C5:{type:"100nF", function:"Decoupling CTRL", 1:VCC, 2:GND},
    C6:{type:"100uF", function:"Bulk power", 1:VCC, 2:GND},
    R2:{type:"10K", function:"/NMI pull-up", 1:VCC, 2:/NMI},
    R3:{type:"10K", function:"/IRQ pull-up", 1:VCC, 2:/IRQ},

    // ═══════════════════════════════════════════
    // DEBUG LEDs (optional)
    // ═══════════════════════════════════════════

    LED_D0:{type:LED, A:D0, K:R_D0.2}, R_D0:{type:"330R", 1:LED_D0.K, 2:GND},
    LED_D1:{type:LED, A:D1, K:R_D1.2}, R_D1:{type:"330R", 1:LED_D1.K, 2:GND},
    LED_D2:{type:LED, A:D2, K:R_D2.2}, R_D2:{type:"330R", 1:LED_D2.K, 2:GND},
    LED_D3:{type:LED, A:D3, K:R_D3.2}, R_D3:{type:"330R", 1:LED_D3.K, 2:GND},
    LED_D4:{type:LED, A:D4, K:R_D4.2}, R_D4:{type:"330R", 1:LED_D4.K, 2:GND},
    LED_D5:{type:LED, A:D5, K:R_D5.2}, R_D5:{type:"330R", 1:LED_D5.K, 2:GND},
    LED_D6:{type:LED, A:D6, K:R_D6.2}, R_D6:{type:"330R", 1:LED_D6.K, 2:GND},
    LED_D7:{type:LED, A:D7, K:R_D7.2}, R_D7:{type:"330R", 1:LED_D7.K, 2:GND},
    LED_CLK:{type:LED, A:CLK, K:R_CLK.2}, R_CLK:{type:"330R", 1:LED_CLK.K, 2:GND},

    // ═══════════════════════════════════════════
    // 40-PIN BUS CONNECTOR
    // ═══════════════════════════════════════════

    RV8-Bus:{type:"40-pin IDC", function:"Expansion bus",
         1:A0,     2:A1,     3:A2,     4:A3,
         5:A4,     6:A5,     7:A6,     8:A7,
         9:A8,    10:A9,    11:A10,   12:A11,
        13:A12,   14:A13,   15:A14,   16:A15,
        17:D0,    18:D1,    19:D2,    20:D3,
        21:D4,    22:D5,    23:D6,    24:D7,
        25:/RD,   26:/WR,   27:CLK,   28:/RST,
        29:/NMI,  30:/IRQ,  31:HALT,  32:SYNC,
        33:/IO_CE,34:,      35:,      36:,
        37:,      38:,      39:VCC,   40:GND}
    }
}
