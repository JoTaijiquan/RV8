{
Project: RV8,
Bus:{
    // === POWER ===
    VCC  : +5V,
    GND  : GND,

    // === RESET + CLOCK ===
    /CLR : Reset (active low) — R1 pull-up + SW_RST to GND + C7 debounce,
    CLK  : Clock (3.5MHz crystal) — OSC pin 8,

    // === ADDRESS BUS (16-bit, active during memory access) ===
    A0:, A1:, A2:, A3:, A4:, A5:, A6:, A7:,
    A8:, A9:, A10:, A11:, A12:, A13:, A14:, A15:,

    // === DATA BUS (8-bit, bidirectional) ===
    D0:, D1:, D2:, D3:, D4:, D5:, D6:, D7:,

    // === MEMORY CONTROL ===
    /RD      : Memory read (active low) — from control logic,
    /WR      : Memory write (active low) — from control logic,

    // === STATE SIGNALS (from U21 FF2 state toggle) ===
    state_F0 : Fetch opcode phase — U21 pin 8 (/Q2),
    state_F1 : Fetch operand phase — U21 pin 9 (Q2),

    // === GATED CLOCKS (from U22 AND gates) ===
    ir0_clk  : Latch opcode — U22 pin 3 (= CLK AND state_F0) → U5 pin 11,
    ir1_clk  : Latch operand — U22 pin 6 (= CLK AND state_F1) → U6 pin 11,

    // === DERIVED CONTROL (from U23 OR gates) ===
    pc_inc   : PC increment enable — U23 pin 3 (= state_F0 OR state_F1) → U1-U4 pin 7+10,

    // === FLAGS (from U20 + U21 FF1) ===
    flag_z   : Zero flag — U20 pin 5 (Q1) — set when ALU result = 0,
    flag_c   : Carry flag — U20 pin 9 (Q2) — set on ALU carry/borrow,
    flag_n   : Negative flag — U21 pin 5 (Q1) — set when ALU result bit 7 = 1,
    flags_clk: Flags latch clock — from control (clocks U20 + U21 FF1),
    alu_zero : ALU result == 0 detect — combinational → U20 pin 2 (D1),
    alu_sign : ALU result bit 7 — from U12/U14 → U21 pin 2 (D1),
    carry_out: ALU carry output — U14 pin 9 (C4) → U20 pin 12 (D2),

    // === REGISTER CLOCKS ===
    a0_clk   : Accumulator write clock — from control → U7 pin 11,
    t0_clk   : Temp register write clock — from control → U8 pin 11,
    sp_clk   : Stack pointer write clock — from control → U9 pin 11,
    pg_clk   : Page register write clock — from control → U10 pin 11,

    // === POINTER CONTROL ===
    ptr_inc  : Pointer auto-increment — from control → U11 pin 7+10 / U12 pin 7,
    pl_ld    : Pointer low load — from control → U11 pin 9,
    ph_ld    : Pointer high load — from control → U12 pin 9,

    // === ADDRESS MUX ===
    addr_sel : Address source select — from control → U16 pin 1 / U17 pin 1,
    //         0 = PC (fetch), 1 = pointer/stack/zp (data access)

    // === DECODE OUTPUTS (from U24) ===
    /Y0  : U24 decode — A[15:13]=000 → RAM $0000-$1FFF,
    /Y1  : U24 decode — A[15:13]=001 → RAM $2000-$3FFF,
    /Y2  : U24 decode — A[15:13]=010 → RAM $4000-$5FFF,
    /Y3  : U24 decode — A[15:13]=011 → RAM $6000-$7FFF,
    /Y4  : U24 decode — A[15:13]=100 → I/O $8000-$9FFF,
    /Y5  : U24 decode — A[15:13]=101 → (unused),
    /Y6  : U24 decode — A[15:13]=110 → ROM $C000-$DFFF,
    /Y7  : U24 decode — A[15:13]=111 → ROM $E000-$FFFF,
    /RAM_CE : RAM chip enable — /Y0 OR /Y1 OR /Y2 OR /Y3 (via U23) → RAM pin 20,
    /ROM_CE : ROM chip enable — /Y6 OR /Y7 (via U23) → ROM pin 20,
    /IO_CE  : I/O chip enable — /Y4 directly → RV8-Bus pin 33,

    // === INSTRUCTION DECODE (from U18) ===
    exec_phase: Execute phase active — from state logic → U18 pin 6 (G1),
    // U18 inputs: A=U5.17(op5), B=U5.18(op6), C=U5.19(op7)
    /Y0_u18: Unit 0 (ALU reg) — U18 pin 15,
    /Y1_u18: Unit 1 (ALU imm) — U18 pin 14,
    /Y2_u18: Unit 2 (Load/Store) — U18 pin 13,
    /Y3_u18: Unit 3 (Branch) — U18 pin 12,
    /Y4_u18: Unit 4 (Shift) — U18 pin 11,
    /Y5_u18: Unit 5 (LI) — U18 pin 10,
    /Y6_u18: Unit 6 (Stack/Jump) — U18 pin 9,
    /Y7_u18: Unit 7 (System) — U18 pin 7,

    // === ALU INTERNAL ===
    sub_mode : SUB/CMP active — from decode → U15 pin 2/5/10/13 (XOR B input),
    carry_in : ALU carry input — 0 for ADD / 1 for SUB → U13 pin 7,
    // ALU A inputs: a0 bits from U7 pins 12-19
    // ALU B inputs: operand bits from U6 pins 12-19 (via U15 XOR for SUB)

    // === BUS BUFFER CONTROL ===
    bus_dir  : Data bus direction — from control → U19 pin 1 (HIGH=read LOW=write),
    bus_oe   : Bus buffer enable — from control → U19 pin 19 (active low),

    // === EXTERNAL (40-pin connector) ===
    SYNC : Instruction start pulse — pin 32,
    HALT : CPU halted — pin 31,
    /NMI : Non-maskable interrupt input — pin 29,
    /IRQ : Maskable interrupt input — pin 30
    },

Part:{
    // ═══════════════════════════════════════════
    // PROGRAM COUNTER — 74HC161 ×4 (U1-U4)
    // ═══════════════════════════════════════════

    U1:{type:74HC161, function:"PC bit 3:0",
        1:/CLR, 2:CLK, 3:D0, 4:D1,
        5:D2, 6:D3, 7:VCC, 8:GND,
        9:VCC, 10:VCC, 11:A3, 12:A2,
        13:A1, 14:A0, 15:U2.10, 16:VCC},

    U2:{type:74HC161, function:"PC bit 7:4",
        1:/CLR, 2:CLK, 3:D4, 4:D5,
        5:D6, 6:D7, 7:VCC, 8:GND,
        9:VCC, 10:U1.15, 11:A7, 12:A6,
        13:A5, 14:A4, 15:U3.10, 16:VCC},

    U3:{type:74HC161, function:"PC bit 11:8",
        1:/CLR, 2:CLK, 3:D0, 4:D1,
        5:D2, 6:D3, 7:VCC, 8:GND,
        9:VCC, 10:U2.15, 11:A11, 12:A10,
        13:A9, 14:A8, 15:U4.10, 16:VCC},

    U4:{type:74HC161, function:"PC bit 15:12",
        1:/CLR, 2:CLK, 3:D4, 4:D5,
        5:D6, 6:D7, 7:VCC, 8:GND,
        9:VCC, 10:U3.15, 11:A15, 12:A14,
        13:A13, 14:A12, 15:, 16:VCC},

    // ═══════════════════════════════════════════
    // INSTRUCTION REGISTER — 74HC574 ×2 (U5-U6)
    // ═══════════════════════════════════════════

    U5:{type:74HC574, function:"IR opcode",
        1:GND, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:ir0_clk, 12:,
        13:, 14:, 15:, 16:,
        17:U18.1, 18:U18.2, 19:U18.3, 20:VCC},
    // pin 1 (/OE) = GND (always output)
    // pin 11 (CLK) = ir0_clk (from U22.3)
    // pin 12 (Q0) = opcode bit 0 → decode logic (op within unit)
    // pin 13 (Q1) = opcode bit 1 → decode logic
    // pin 14 (Q2) = opcode bit 2 → decode logic
    // pin 15 (Q3) = opcode bit 3 → decode logic
    // pin 16 (Q4) = opcode bit 4 → decode logic
    // pin 17 (Q5) = opcode bit 5 → U18 pin 1 (A) — unit select
    // pin 18 (Q6) = opcode bit 6 → U18 pin 2 (B) — unit select
    // pin 19 (Q7) = opcode bit 7 → U18 pin 3 (C) — unit select

    U6:{type:74HC574, function:"IR operand",
        1:GND, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:ir1_clk, 12:U15.1,
        13:U15.4, 14:U15.9, 15:U15.12, 16:,
        17:, 18:, 19:, 20:VCC},
    // pin 1 (/OE) = GND (always output)
    // pin 11 (CLK) = ir1_clk (from U22.6)
    // pin 12 (Q0) = operand bit 0 → U15.1 (XOR gate A input) → ALU B0
    // pin 13 (Q1) = operand bit 1 → U15.4 (XOR gate A input) → ALU B1
    // pin 14 (Q2) = operand bit 2 → U15.9 (XOR gate A input) → ALU B2
    // pin 15 (Q3) = operand bit 3 → U15.12 (XOR gate A input) → ALU B3
    // pin 16 (Q4) = operand bit 4 → ALU B4 (needs 2nd XOR chip or direct)
    // pin 17 (Q5) = operand bit 5 → ALU B5
    // pin 18 (Q6) = operand bit 6 → ALU B6
    // pin 19 (Q7) = operand bit 7 → ALU B7
    // ALL Q0-Q7 also → address mux (U16/U17) for immediate addressing
    // ALL Q0-Q7 also → PC load data (for branch offset)

    // ═══════════════════════════════════════════
    // REGISTERS — 74HC574 ×4 (U7-U10)
    // ═══════════════════════════════════════════

    U7:{type:74HC574, function:"a0 (accumulator)",
        1:GND, 2:U11.4, 3:U11.1, 4:U11.13,
        5:U11.10, 6:U12.4, 7:U12.1, 8:U12.13,
        9:U12.10, 10:GND, 11:a0_clk, 12:a0_0,
        13:a0_1, 14:a0_2, 15:a0_3, 16:a0_4,
        17:a0_5, 18:a0_6, 19:a0_7, 20:VCC},

    U8:{type:74HC574, function:"t0 (temporary)",
        1:GND, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:t0_clk, 12:t0_0,
        13:t0_1, 14:t0_2, 15:t0_3, 16:t0_4,
        17:t0_5, 18:t0_6, 19:t0_7, 20:VCC},

    U9:{type:74HC574, function:"sp (stack pointer)",
        1:GND, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:sp_clk, 12:sp_0,
        13:sp_1, 14:sp_2, 15:sp_3, 16:sp_4,
        17:sp_5, 18:sp_6, 19:sp_7, 20:VCC},

    U10:{type:74HC574, function:"pg (page register)",
        1:GND, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:pg_clk, 12:pg_0,
        13:pg_1, 14:pg_2, 15:pg_3, 16:pg_4,
        17:pg_5, 18:pg_6, 19:pg_7, 20:VCC},

    // ═══════════════════════════════════════════
    // POINTER — 74HC161 ×2 (U11-U12)
    // ═══════════════════════════════════════════

    U11:{type:74HC161, function:"pl (pointer low)",
        1:/CLR, 2:CLK, 3:D0, 4:D1,
        5:D2, 6:D3, 7:ptr_inc, 8:GND,
        9:pl_ld, 10:ptr_inc, 11:pl_3, 12:pl_2,
        13:pl_1, 14:pl_0, 15:U12.10, 16:VCC},

    U12:{type:74HC161, function:"ph (pointer high)",
        1:/CLR, 2:CLK, 3:D0, 4:D1,
        5:D2, 6:D3, 7:ptr_inc, 8:GND,
        9:ph_ld, 10:U11.15, 11:ph_3, 12:ph_2,
        13:ph_1, 14:ph_0, 15:, 16:VCC},

    // ═══════════════════════════════════════════
    // ALU — 74HC283 ×2 + 74HC86 (U13-U15)
    // ═══════════════════════════════════════════

    U13:{type:74HC283, function:"ALU adder low nibble",
        1:sum_1, 2:alu_b_1, 3:a0_1, 4:sum_0,
        5:a0_0, 6:alu_b_0, 7:carry_in, 8:GND,
        9:U14.7, 10:sum_3, 11:alu_b_3, 12:a0_3,
        13:sum_2, 14:a0_2, 15:alu_b_2, 16:VCC},

    U14:{type:74HC283, function:"ALU adder high nibble",
        1:sum_5, 2:alu_b_5, 3:a0_5, 4:sum_4,
        5:a0_4, 6:alu_b_4, 7:U13.9, 8:GND,
        9:carry_out, 10:sum_7, 11:alu_b_7, 12:a0_7,
        13:sum_6, 14:a0_6, 15:alu_b_6, 16:VCC},

    U15:{type:74HC86, function:"XOR (SUB invert + XOR op)",
        1:OPR0, 2:sub_mode, 3:alu_b_0, 4:OPR1,
        5:sub_mode, 6:alu_b_1, 7:GND, 8:alu_b_2,
        9:OPR2, 10:sub_mode, 11:alu_b_3, 12:OPR3,
        13:sub_mode, 14:VCC},

    // ═══════════════════════════════════════════
    // ADDRESS MUX — 74HC157 ×2 (U16-U17)
    // ═══════════════════════════════════════════

    U16:{type:74HC157, function:"Address mux low byte",
        1:addr_sel, 2:A0, 3:pl_0, 4:A0_out,
        5:A1, 6:pl_1, 7:A1_out, 8:GND,
        9:A2_out, 10:pl_2, 11:A2, 12:A3_out,
        13:pl_3, 14:A3, 15:GND, 16:VCC},

    U17:{type:74HC157, function:"Address mux high byte",
        1:addr_sel, 2:A4, 3:ph_0, 4:A4_out,
        5:A5, 6:ph_1, 7:A5_out, 8:GND,
        9:A6_out, 10:ph_2, 11:A6, 12:A7_out,
        13:ph_3, 14:A7, 15:GND, 16:VCC},

    // ═══════════════════════════════════════════
    // INSTRUCTION DECODE — 74HC138 (U18)
    // ═══════════════════════════════════════════

    U18:{type:74HC138, function:"Instruction unit decode",
        1:OP5, 2:OP6, 3:OP7, 4:GND,
        5:GND, 6:exec_phase, 7:/Y7, 8:GND,
        9:/Y6, 10:/Y5, 11:/Y4, 12:/Y3,
        13:/Y2, 14:/Y1, 15:/Y0, 16:VCC},

    // ═══════════════════════════════════════════
    // BUS BUFFER — 74HC245 (U19)
    // ═══════════════════════════════════════════

    U19:{type:74HC245, function:"Data bus buffer",
        1:bus_dir, 2:D0_int, 3:D1_int, 4:D2_int,
        5:D3_int, 6:D4_int, 7:D5_int, 8:D6_int,
        9:D7_int, 10:GND, 11:D7, 12:D6,
        13:D5, 14:D4, 15:D3, 16:D2,
        17:D1, 18:D0, 19:bus_oe, 20:VCC},

    // ═══════════════════════════════════════════
    // FLAGS + STATE — 74HC74 ×2 (U20-U21)
    // ═══════════════════════════════════════════

    U20:{type:74HC74, function:"Flags Z, C",
        1:/CLR, 2:alu_zero, 3:flags_clk, 4:VCC,
        5:flag_z, 6:flag_z_n, 7:GND, 8:flag_c_n,
        9:flag_c, 10:VCC, 11:flags_clk, 12:carry_out,
        13:/CLR, 14:VCC},

    U21:{type:74HC74, function:"N flag + state toggle",
        1:/CLR, 2:alu_sign, 3:flags_clk, 4:VCC,
        5:flag_n, 6:, 7:GND, 8:state_F0,
        9:state_F1, 10:VCC, 11:CLK, 12:U21.8,
        13:/CLR, 14:VCC},
    // FF1 (pins 1-6): N flag — D=ALU result bit 7, Q=flag_n
    // FF2 (pins 8-13): State toggle — D=/Q (pin 8 fed back to pin 12)
    //   pin 9 (Q2)  = state_F1 → U22.5, U23.2
    //   pin 8 (/Q2) = state_F0 → U22.2, U23.1

    // ═══════════════════════════════════════════
    // CONTROL LOGIC — 74HC08 + 74HC32 (U22-U23)
    // ═══════════════════════════════════════════

    U22:{type:74HC08, function:"AND gates (clock gating)",
        1:CLK, 2:U21.8, 3:U5.11, 4:CLK,
        5:U21.9, 6:U6.11, 7:GND, 8:,
        9:, 10:, 11:, 12:,
        13:, 14:VCC},
    // pin 1,2→3: CLK AND state_F0(/Q2) = ir0_clk → U5 CLK (latch opcode)
    // pin 4,5→6: CLK AND state_F1(Q2)  = ir1_clk → U6 CLK (latch operand)
    // pin 9,10→8: (spare, for future control)
    // pin 12,13→11: (spare)

    U23:{type:74HC32, function:"OR gates (signal combining)",
        1:U21.8, 2:U21.9, 3:pc_inc, 4:U24.11,
        5:U24.10, 6:/ROM_CE, 7:GND, 8:,
        9:, 10:, 11:, 12:,
        13:, 14:VCC},
    // pin 1,2→3: state_F0 OR state_F1 = pc_inc → U1.7, U1.10, U2.7, U3.7, U4.7
    // pin 4,5→6: /Y4 OR /Y5 = (not used, example)
    //            Actually: /Y6 OR /Y7 → /ROM_CE → ROM pin 20
    // pin 9,10→8: /Y0 OR /Y1 (partial /RAM_CE, need more gates)
    // pin 12,13→11: (spare)

    // NOTE: Full 17-state machine needs additional state bits.
    // For basic 2-cycle (F0/F1) build, U21 FF2 toggles each clock.
    // For full CPU, state counter or additional 74HC74 required.

    // ═══════════════════════════════════════════
    // ADDRESS DECODE — 74HC138 (U24)
    // ═══════════════════════════════════════════

    U24:{type:74HC138, function:"Address decode (ROM/RAM/IO)",
        1:A13, 2:A14, 3:A15, 4:GND,
        5:GND, 6:VCC, 7:/Y7, 8:GND,
        9:/Y6, 10:/Y5, 11:/Y4, 12:/Y3,
        13:/Y2, 14:/Y1, 15:/Y0, 16:VCC},
    // /Y0+/Y1+/Y2+/Y3 → U23 OR gate → /RAM_CE → RAM pin 20
    // /Y6+/Y7 → U23 OR gate → /ROM_CE → ROM pin 20
    // /Y4 → /IO_CE → RV8-Bus pin 33 (directly, no gate needed)
    // /Y5 → unused (float)

    // ═══════════════════════════════════════════
    // ROM — AT28C256 (32KB)
    // ═══════════════════════════════════════════

    ROM:{type:AT28C256, function:"Program ROM 32KB ($C000-$FFFF)",
        1:A14, 2:A12, 3:A7, 4:A6,
        5:A5, 6:A4, 7:A3, 8:A2,
        9:A1, 10:A0, 11:D0, 12:D1,
        13:D2, 14:GND, 15:D3, 16:D4,
        17:D5, 18:D6, 19:D7, 20:/ROM_CE,
        21:A10, 22:/RD, 23:A11, 24:A9,
        25:A8, 26:A13, 27:VCC, 28:VCC},

    // ═══════════════════════════════════════════
    // RAM — 62256 (32KB)
    // ═══════════════════════════════════════════

    RAM:{type:62256, function:"Data RAM 32KB ($0000-$7FFF)",
        1:A14, 2:A12, 3:A7, 4:A6,
        5:A5, 6:A4, 7:A3, 8:A2,
        9:A1, 10:A0, 11:D0, 12:D1,
        13:D2, 14:GND, 15:D3, 16:D4,
        17:D5, 18:D6, 19:D7, 20:/RAM_CE,
        21:A10, 22:/RD, 23:A11, 24:A9,
        25:A8, 26:A13, 27:/WR, 28:VCC},

    // ═══════════════════════════════════════════
    // CRYSTAL OSCILLATOR
    // ═══════════════════════════════════════════

    OSC:{type:"Crystal Oscillator 3.5MHz", function:"Clock source",
        1:VCC, 7:GND, 8:CLK, 14:},

    // ═══════════════════════════════════════════
    // DECOUPLING CAPACITORS
    // ═══════════════════════════════════════════

    C1:{type:"100nF", function:"Decoupling near OSC", 1:VCC, 2:GND},
    C2:{type:"100nF", function:"Decoupling near ROM", 1:VCC, 2:GND},
    C3:{type:"100nF", function:"Decoupling near RAM", 1:VCC, 2:GND},
    C4:{type:"100nF", function:"Decoupling near U18", 1:VCC, 2:GND},
    C5:{type:"100nF", function:"Decoupling near U24", 1:VCC, 2:GND},
    C6:{type:"100uF", function:"Bulk power filter", 1:VCC, 2:GND},
    C7:{type:"100nF", function:"Reset debounce", 1:/CLR, 2:GND},

    // ═══════════════════════════════════════════
    // RESET CIRCUIT
    // ═══════════════════════════════════════════

    R1:{type:"10K", function:"Reset pull-up", 1:VCC, 2:/CLR},
    SW_RST:{type:"Pushbutton", function:"Reset button", 1:/CLR, 2:GND},

    // ═══════════════════════════════════════════
    // LEDs (optional debug)
    // ═══════════════════════════════════════════

    LED_D0:{type:LED, A:D0, K:R_LED0.2},
    LED_D1:{type:LED, A:D1, K:R_LED1.2},
    LED_D2:{type:LED, A:D2, K:R_LED2.2},
    LED_D3:{type:LED, A:D3, K:R_LED3.2},
    LED_D4:{type:LED, A:D4, K:R_LED4.2},
    LED_D5:{type:LED, A:D5, K:R_LED5.2},
    LED_D6:{type:LED, A:D6, K:R_LED6.2},
    LED_D7:{type:LED, A:D7, K:R_LED7.2},

    R_LED0:{type:"330R", 1:LED_D0.K, 2:GND},
    R_LED1:{type:"330R", 1:LED_D1.K, 2:GND},
    R_LED2:{type:"330R", 1:LED_D2.K, 2:GND},
    R_LED3:{type:"330R", 1:LED_D3.K, 2:GND},
    R_LED4:{type:"330R", 1:LED_D4.K, 2:GND},
    R_LED5:{type:"330R", 1:LED_D5.K, 2:GND},
    R_LED6:{type:"330R", 1:LED_D6.K, 2:GND},
    R_LED7:{type:"330R", 1:LED_D7.K, 2:GND},

    LED_CLK:{type:LED, A:CLK, K:R_CLK.2},
    R_CLK:{type:"330R", 1:LED_CLK.K, 2:GND},

    LED_RST:{type:LED, A:/CLR, K:R_RST.2},
    R_RST:{type:"330R", 1:LED_RST.K, 2:GND},

    // ═══════════════════════════════════════════
    // 40-PIN BUS CONNECTOR
    // ═══════════════════════════════════════════

    RV8-Bus:{type:"40-pin IDC", function:"Expansion bus",
         1:A0,   2:A1,   3:A2,   4:A3,
         5:A4,   6:A5,   7:A6,   8:A7,
         9:A8,  10:A9,  11:A10, 12:A11,
        13:A12, 14:A13, 15:A14, 16:A15,
        17:D0,  18:D1,  19:D2,  20:D3,
        21:D4,  22:D5,  23:D6,  24:D7,
        25:/RD, 26:/WR, 27:CLK, 28:/CLR,
        29:/NMI,30:/IRQ,31:HALT,32:SYNC,
        33:/IO_CE, 34:,  35:,   36:,
        37:,    38:,    39:VCC, 40:GND}
    }
}
