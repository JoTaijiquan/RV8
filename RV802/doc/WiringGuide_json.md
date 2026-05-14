{
// RV802 — WiringGuide (JSON-style format)
// 25 logic chips + ROM + RAM = 27 packages
// Single 8-bit bus, Flash microcode, RISC-V style

Project: RV802,

Bus:{
    VCC  : +5V,
    GND  : GND,
    CLK  : Clock 10MHz (PCB) / 3.5MHz (breadboard),
    /RST : Reset — 10K pull-up + 100nF + pushbutton,
    IBUS0: Internal bus bit 0 (shared by all registers + ALU),
    IBUS1:, IBUS2:, IBUS3:, IBUS4:, IBUS5:, IBUS6:, IBUS7:,
    A0:, A1:, A2:, A3:, A4:, A5:, A6:, A7:,
    A8:, A9:, A10:, A11:, A12:, A13:, A14:, A15:,
    /RD  : Memory read — from microcode Flash D0,
    /WR  : Memory write — from microcode Flash D1,
    reg_sel[2:0]: Which register drives bus — from Flash → U20 (138),
    reg_clk[2:0]: Which register latches from ALU — from Flash → U21 (238),
    alu_sub: SUB mode — from Flash → U14+U15 XOR B inputs,
    ir_clk : Latch opcode — from Flash,
    opr_clk: Latch operand — from Flash,
    alu_b_clk: Latch ALU B — from Flash,
    alu_r_clk: Latch ALU result — from Flash,
    pc_inc : PC increment — from Flash,
    pc_ld  : PC load — from Flash,
    flags_clk: Latch flags — from Flash,
    bus_dir: 245 direction — from Flash,
    bus_oe : 245 enable — from Flash
},

Part:{
    // === REGISTERS r0-r7 (74HC574 ×8) ===
    U1:{type:74HC574, function:"r0 (always zero)",
        1:U20.15, 2:IBUS0, 3:IBUS1, 4:IBUS2, 5:IBUS3,
        6:IBUS4, 7:IBUS5, 8:IBUS6, 9:IBUS7, 10:GND,
        11:GND, 12:ALU_R0, 13:ALU_R1, 14:ALU_R2, 15:ALU_R3,
        16:ALU_R4, 17:ALU_R5, 18:ALU_R6, 19:ALU_R7, 20:VCC},
    // /OE(1)=U20./Y0, CLK(11)=GND(never write), D(2-9)=IBUS, Q(12-19)=ALU result bus (unused, always 0)

    U2:{type:74HC574, function:"r1 (a0/return value)",
        1:U20.14, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.14, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},
    // /OE(1)=U20./Y1 (drives IBUS when selected)
    // CLK(11)=U21./Y1 (latches from ALU result)
    // D(2-9)=ALU result, Q(12-19)=IBUS

    U3:{type:74HC574, function:"r2 (a1/arg1)", 
        1:U20.13, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.13, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    U4:{type:74HC574, function:"r3 (t0)", 
        1:U20.12, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.12, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    U5:{type:74HC574, function:"r4 (t1)",
        1:U20.11, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.11, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    U6:{type:74HC574, function:"r5 (s0)",
        1:U20.10, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.10, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    U7:{type:74HC574, function:"r6 (s1/page)",
        1:U20.9, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.9, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    U8:{type:74HC574, function:"r7 (sp)",
        1:U20.7, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.7, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},
    // All registers: /OE from U20 (read select), CLK from U21 (write select)
    // D inputs from ALU result bus, Q outputs to IBUS

    // === IR + ALU LATCH ===
    U9:{type:74HC574, function:"IR opcode",
        1:GND, 2:IBUS0, 3:IBUS1, 4:IBUS2, 5:IBUS3,
        6:IBUS4, 7:IBUS5, 8:IBUS6, 9:IBUS7, 10:GND,
        11:ir_clk, 12:OP0, 13:OP1, 14:OP2, 15:OP3,
        16:OP4, 17:OP5, 18:OP6, 19:OP7, 20:VCC},
    // /OE=GND (always output), Q→Flash address + decode

    U10:{type:74HC574, function:"IR operand (also ALU B for immediate)",
        1:opr_oe, 2:IBUS0, 3:IBUS1, 4:IBUS2, 5:IBUS3,
        6:IBUS4, 7:IBUS5, 8:IBUS6, 9:IBUS7, 10:GND,
        11:opr_clk, 12:ALUB0, 13:ALUB1, 14:ALUB2, 15:ALUB3,
        16:ALUB4, 17:ALUB5, 18:ALUB6, 19:ALUB7, 20:VCC},
    // /OE=opr_oe (drives ALU B for immediate ops)

    U11:{type:74HC574, function:"ALU B latch (for reg-reg ops)",
        1:alub_oe, 2:IBUS0, 3:IBUS1, 4:IBUS2, 5:IBUS3,
        6:IBUS4, 7:IBUS5, 8:IBUS6, 9:IBUS7, 10:GND,
        11:alu_b_clk, 12:ALUB0, 13:ALUB1, 14:ALUB2, 15:ALUB3,
        16:ALUB4, 17:ALUB5, 18:ALUB6, 19:ALUB7, 20:VCC},
    // Shares ALUB lines with U10 (only one /OE active at a time)

    // === ALU (74HC283 ×2 + 74HC86 ×2) ===
    U12:{type:74HC283, function:"ALU adder low nibble",
        1:ALU_R1, 2:XOR1, 3:IBUS1, 4:ALU_R0,
        5:IBUS0, 6:XOR0, 7:alu_sub, 8:GND,
        9:U13.7, 10:ALU_R3, 11:XOR3, 12:IBUS3,
        13:ALU_R2, 14:IBUS2, 15:XOR2, 16:VCC},
    // A inputs from IBUS (selected register), B from XOR output, C0=alu_sub

    U13:{type:74HC283, function:"ALU adder high nibble",
        1:ALU_R5, 2:XOR5, 3:IBUS5, 4:ALU_R4,
        5:IBUS4, 6:XOR4, 7:U12.9, 8:GND,
        9:carry_out, 10:ALU_R7, 11:XOR7, 12:IBUS7,
        13:ALU_R6, 14:IBUS6, 15:XOR6, 16:VCC},

    U14:{type:74HC86, function:"XOR low nibble (SUB invert)",
        1:ALUB0, 2:alu_sub, 3:XOR0, 4:ALUB1,
        5:alu_sub, 6:XOR1, 7:GND, 8:XOR2,
        9:ALUB2, 10:alu_sub, 11:XOR3, 12:ALUB3,
        13:alu_sub, 14:VCC},

    U15:{type:74HC86, function:"XOR high nibble (SUB invert)",
        1:ALUB4, 2:alu_sub, 3:XOR4, 4:ALUB5,
        5:alu_sub, 6:XOR5, 7:GND, 8:XOR6,
        9:ALUB6, 10:alu_sub, 11:XOR7, 12:ALUB7,
        13:alu_sub, 14:VCC},

    // === PC (74HC161 ×4) ===
    U16:{type:74HC161, function:"PC bit 3:0",
        1:/RST, 2:CLK, 3:IBUS0, 4:IBUS1, 5:IBUS2, 6:IBUS3,
        7:pc_inc, 8:GND, 9:pc_ld, 10:pc_inc,
        11:A3, 12:A2, 13:A1, 14:A0, 15:U17.10, 16:VCC},

    U17:{type:74HC161, function:"PC bit 7:4",
        1:/RST, 2:CLK, 3:IBUS4, 4:IBUS5, 5:IBUS6, 6:IBUS7,
        7:pc_inc, 8:GND, 9:pc_ld, 10:U16.15,
        11:A7, 12:A6, 13:A5, 14:A4, 15:U18.10, 16:VCC},

    U18:{type:74HC161, function:"PC bit 11:8",
        1:/RST, 2:CLK, 3:IBUS0, 4:IBUS1, 5:IBUS2, 6:IBUS3,
        7:pc_inc, 8:GND, 9:pc_ld, 10:U17.15,
        11:A11, 12:A10, 13:A9, 14:A8, 15:U19.10, 16:VCC},

    U19:{type:74HC161, function:"PC bit 15:12",
        1:/RST, 2:CLK, 3:IBUS4, 4:IBUS5, 5:IBUS6, 6:IBUS7,
        7:pc_inc, 8:GND, 9:pc_ld, 10:U18.15,
        11:A15, 12:A14, 13:A13, 14:A12, 15:, 16:VCC},

    // === DECODE + CONTROL ===
    U20:{type:74HC138, function:"Register READ select (which drives IBUS)",
        1:reg_sel0, 2:reg_sel1, 3:reg_sel2, 4:GND,
        5:GND, 6:VCC, 7:/Y7, 8:GND,
        9:/Y6, 10:/Y5, 11:/Y4, 12:/Y3,
        13:/Y2, 14:/Y1, 15:/Y0, 16:VCC},
    // /Y0→U1./OE, /Y1→U2./OE, ..., /Y7→U8./OE

    U21:{type:74HC138, function:"Register WRITE select (which latches from ALU)",
        1:reg_clk0, 2:reg_clk1, 3:reg_clk2, 4:GND,
        5:GND, 6:write_en, 7:/Y7, 8:GND,
        9:/Y6, 10:/Y5, 11:/Y4, 12:/Y3,
        13:/Y2, 14:/Y1, 15:/Y0, 16:VCC},
    // G1=write_en (only fires when microcode says write)
    // /Y1→U2.CLK, /Y2→U3.CLK, ..., /Y7→U8.CLK

    U22:{type:74HC245, function:"External bus buffer",
        1:bus_dir, 2:IBUS0, 3:IBUS1, 4:IBUS2, 5:IBUS3,
        6:IBUS4, 7:IBUS5, 8:IBUS6, 9:IBUS7, 10:GND,
        11:D7, 12:D6, 13:D5, 14:D4, 15:D3,
        16:D2, 17:D1, 18:D0, 19:bus_oe, 20:VCC},

    U23:{type:SST39SF010A, function:"Microcode Flash (70ns PDIP-32)",
        // Address: {step[1:0], opcode[7:0], flags[1:0]} = 12 bits
        1:, 2:, 3:OP7, 4:OP6, 5:OP5, 6:OP4,
        7:OP3, 8:OP2, 9:OP1, 10:OP0, 11:D0_ctrl,
        12:D1_ctrl, 13:D2_ctrl, 14:GND, 15:D3_ctrl,
        16:D4_ctrl, 17:D5_ctrl, 18:D6_ctrl, 19:D7_ctrl,
        20:GND, 21:step1, 22:GND, 23:flag_z,
        24:step0, 25:flag_c, 26:, 27:VCC, 28:VCC,
        29:, 30:, 31:VCC, 32:VCC},

    U24:{type:74HC74, function:"Flags Z + C",
        1:/RST, 2:alu_zero, 3:flags_clk, 4:VCC,
        5:flag_z, 6:, 7:GND, 8:,
        9:flag_c, 10:VCC, 11:flags_clk, 12:carry_out,
        13:/RST, 14:VCC},

    U25:{type:74HC574, function:"ALU result latch",
        1:GND, 2:U12.4, 3:U12.1, 4:U12.13, 5:U12.10,
        6:U13.4, 7:U13.1, 8:U13.13, 9:U13.10, 10:GND,
        11:alu_r_clk, 12:ALU_R0, 13:ALU_R1, 14:ALU_R2, 15:ALU_R3,
        16:ALU_R4, 17:ALU_R5, 18:ALU_R6, 19:ALU_R7, 20:VCC},
    // D from adder outputs, Q to all register D inputs (ALU_R bus)

    // === MEMORY ===
    ROM:{type:AT28C256, function:"Program ROM ($C000-$FFFF)",
        1:A14, 2:A12, 3:A7, 4:A6, 5:A5, 6:A4, 7:A3, 8:A2,
        9:A1, 10:A0, 11:D0, 12:D1, 13:D2, 14:GND, 15:D3,
        16:D4, 17:D5, 18:D6, 19:D7, 20:/ROM_CE,
        21:A10, 22:/RD, 23:A11, 24:A9, 25:A8, 26:A13, 27:VCC, 28:VCC},

    RAM:{type:62256, function:"Data RAM ($0000-$7FFF)",
        1:A14, 2:A12, 3:A7, 4:A6, 5:A5, 6:A4, 7:A3, 8:A2,
        9:A1, 10:A0, 11:D0, 12:D1, 13:D2, 14:GND, 15:D3,
        16:D4, 17:D5, 18:D6, 19:D7, 20:/RAM_CE,
        21:A10, 22:/RD, 23:A11, 24:A9, 25:A8, 26:A13, 27:/WR, 28:VCC},

    // === SUPPORT ===
    OSC:{type:"Crystal 3.5MHz/10MHz", 1:VCC, 7:GND, 8:CLK, 14:},
    R1:{type:"10K", 1:VCC, 2:/RST},
    SW_RST:{type:"Pushbutton", 1:/RST, 2:GND},
    C1:{type:"100nF", 1:/RST, 2:GND},

    // === 40-PIN BUS ===
    RV8_Bus:{type:"40-pin IDC",
        1:A0, 2:A1, 3:A2, 4:A3, 5:A4, 6:A5, 7:A6, 8:A7,
        9:A8, 10:A9, 11:A10, 12:A11, 13:A12, 14:A13, 15:A14, 16:A15,
        17:D0, 18:D1, 19:D2, 20:D3, 21:D4, 22:D5, 23:D6, 24:D7,
        25:/RD, 26:/WR, 27:CLK, 28:/RST, 29:/NMI, 30:/IRQ,
        31:HALT, 32:SYNC, 33:/IO_CE, 34:, 35:, 36:,
        37:, 38:, 39:VCC, 40:GND}
    }
}
