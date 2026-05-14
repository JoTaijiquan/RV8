{
Project: RV8,
Bus:{
    VCC  : +5V,
    GND  : GND,
    /CLR : Reset (active low),
    CLK  : Clock (3.5MHz crystal),
    A0:, A1:, A2:, A3:, A4:, A5:, A6:, A7:,
    A8:, A9:, A10:, A11:, A12:, A13:, A14:, A15:,
    D0:, D1:, D2:, D3:, D4:, D5:, D6:, D7:,
    /RD  : Memory read,
    /WR  : Memory write,
    SYNC : Instruction start pulse,
    HALT : CPU halted,
    /RAM_CE : RAM chip enable (active when A[15:13]=000-011 → $0000-$7FFF),
    /ROM_CE : ROM chip enable (active when A[15:13]=110-111 → $C000-$FFFF),
    /IO_CE  : I/O chip enable (active when A[15:13]=100 → $8000-$9FFF),
    /Y0  : U24 decode — A[15:13]=000 → RAM $0000-$1FFF,
    /Y1  : U24 decode — A[15:13]=001 → RAM $2000-$3FFF,
    /Y2  : U24 decode — A[15:13]=010 → RAM $4000-$5FFF,
    /Y3  : U24 decode — A[15:13]=011 → RAM $6000-$7FFF,
    /Y4  : U24 decode — A[15:13]=100 → I/O $8000-$9FFF,
    /Y5  : U24 decode — A[15:13]=101 → (unused),
    /Y6  : U24 decode — A[15:13]=110 → ROM $C000-$DFFF,
    /Y7  : U24 decode — A[15:13]=111 → ROM $E000-$FFFF
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
        9:D7, 10:GND, 11:U22.3, 12:OP0,
        13:OP1, 14:OP2, 15:OP3, 16:OP4,
        17:OP5, 18:OP6, 19:OP7, 20:VCC},

    U6:{type:74HC574, function:"IR operand",
        1:GND, 2:D0, 3:D1, 4:D2,
        5:D3, 6:D4, 7:D5, 8:D6,
        9:D7, 10:GND, 11:U22.6, 12:OPR0,
        13:OPR1, 14:OPR2, 15:OPR3, 16:OPR4,
        17:OPR5, 18:OPR6, 19:OPR7, 20:VCC},

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

    U21:{type:74HC74, function:"N flag + state",
        1:/CLR, 2:alu_sign, 3:flags_clk, 4:VCC,
        5:flag_n, 6:flag_n_n, 7:GND, 8:state_n,
        9:state, 10:VCC, 11:CLK, 12:state_next,
        13:/CLR, 14:VCC},

    // ═══════════════════════════════════════════
    // CONTROL LOGIC — 74HC08 + 74HC32 (U22-U23)
    // ═══════════════════════════════════════════

    U22:{type:74HC08, function:"AND gates (clock gating)",
        1:CLK, 2:state_F0, 3:ir0_clk, 4:CLK,
        5:state_F1, 6:ir1_clk, 7:GND, 8:skip_gate,
        9:write_en, 10:not_skip, 11:int_gate, 12:nmi_pend,
        13:not_skip, 14:VCC},

    U23:{type:74HC32, function:"OR gates (signal combining)",
        1:state_F0, 2:state_F1, 3:pc_inc, 4:state_M1,
        5:state_M2, 6:data_access, 7:GND, 8:,
        9:, 10:, 11:, 12:,
        13:, 14:VCC},

    // ═══════════════════════════════════════════
    // ADDRESS DECODE — 74HC138 (U24)
    // ═══════════════════════════════════════════

    U24:{type:74HC138, function:"Address decode (ROM/RAM/IO)",
        1:A13, 2:A14, 3:A15, 4:GND,
        5:GND, 6:VCC, 7:/Y7, 8:GND,
        9:/Y6, 10:/Y5, 11:/Y4, 12:/Y3,
        13:/Y2, 14:/Y1, 15:/Y0, 16:VCC},
    // /Y0-/Y3 → OR together → /RAM_CE (RAM.20)
    // /Y4 → /IO_CE (to expansion bus)
    // /Y5 → unused
    // /Y6,/Y7 → OR together → /ROM_CE (ROM.20)

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
        33:,    34:,    35:,    36:,
        37:,    38:,    39:VCC, 40:GND}
    }
}
