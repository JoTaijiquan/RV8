{
// ═══════════════════════════════════════════════════════════════
// RV8 CPU — WiringGuide (JSON format)
// 25 logic chips + ROM + RAM = 27 packages
// Single 8-bit bus, Flash microcode, RISC-V style
// ═══════════════════════════════════════════════════════════════
//
// ARCHITECTURE:
//   One internal bus (IBUS). Microcode controls who drives/latches.
//   PC is 74HC574 (has /OE) — can disconnect from address bus.
//   Address latches hold address during data access.
//   ALU result goes directly to register D inputs (not through IBUS).
//
// SPEED: ~2.17 MIPS @ 10 MHz (avg 4.6 micro-steps/instruction)
// ═══════════════════════════════════════════════════════════════

Project: RV8,

Bus:{
    // === POWER ===
    VCC  : +5V,
    GND  : GND,

    // === CLOCK + RESET ===
    CLK  : 10 MHz (PCB) / 3.5 MHz (breadboard) — from crystal oscillator,
    /RST : Reset — 10K pull-up + 100nF debounce + pushbutton to GND,

    // === INTERNAL BUS (8-bit, tri-state, one driver at a time) ===
    IBUS[7:0] : Shared by all registers — only ONE /OE active at a time,

    // === ADDRESS BUS (directly to ROM + RAM address pins) ===
    ADDR[15:0] : Driven by PC (fetch) OR address latches (data access),
    //   During fetch: U16+U17 (PC) /OE=LOW → drives ADDR
    //   During data:  U18+U19 (addr latch) /OE=LOW → drives ADDR
    //   Control: DATA_MODE signal switches between them

    // === EXTERNAL DATA (ROM/RAM data pins, via U22 buffer) ===
    DEXT[7:0] : ROM/RAM D[7:0] ↔ U22 (74HC245) ↔ IBUS,

    // === ALU RESULT BUS (direct to register D inputs, NOT on IBUS) ===
    ALU_R[7:0] : From U25 (result latch) Q → all register D inputs,

    // === ALU B INPUT (from operand OR B-latch, selected by /OE) ===
    ALUB[7:0] : Shared by U10 and U11 (only one /OE active),

    // === CONTROL (from microcode Flash U23) ===
    DATA_MODE : 0=fetch(PC drives addr) 1=data(latches drive addr),
    REG_RD[2:0] : Which register drives IBUS → U20 (138) A/B/C,
    REG_WR_EN : Enable register write → U21 (138) G1,
    REG_WR[2:0] : Which register latches ALU_R → U21 A/B/C,
    IR_CLK   : Latch opcode from IBUS → U9.CLK,
    OPR_CLK  : Latch operand from IBUS → U10.CLK,
    ALUB_CLK : Latch ALU B from IBUS → U11.CLK,
    ALUR_CLK : Latch ALU result → U25.CLK,
    ADDR_LO_CLK : Latch address low from IBUS → U18.CLK,
    ADDR_HI_CLK : Latch address high from IBUS → U19.CLK,
    PC_LO_CLK : Load PC low from ALU_R → U16.CLK,
    PC_HI_CLK : Load PC high from ALU_R → U17.CLK,
    BUF_OE   : Enable external bus buffer → U22./OE,
    BUF_DIR  : Buffer direction → U22.DIR (0=ext→IBUS, 1=IBUS→ext),
    ALU_SUB  : SUB mode → U14+U15 XOR B input (inverts ALUB),
    FLAGS_CLK: Latch flags → U24.CLK,
    /RD      : Memory read → ROM./OE + RAM./OE,
    /WR      : Memory write → RAM./WE,
    /IRQ     : Interrupt request (active low level) → Flash A13 (pin 1),
    //         When LOW at step 0: microcode enters interrupt sequence
    //         Sequence: push PC → load vector ($0008) → jump to handler
    //         Software clears IRQ source before RET
    /NMI     : (reserved on bus pin 29 — needs edge-detect FF for future)
},

Part:{
    // ═══════════════════════════════════════════
    // REGISTERS r0-r7 — 74HC574 ×8 (U1-U8)
    // All identical wiring pattern:
    //   /OE → from U20 (read decoder, one active at a time)
    //   CLK → from U21 (write decoder, fires on write)
    //   D[7:0] ← ALU_R[7:0] (result bus, always connected)
    //   Q[7:0] → IBUS[7:0] (only when /OE=LOW)
    // ═══════════════════════════════════════════

    U1:{type:74HC574, function:"r0 (always zero — CLK tied to GND)",
        1:U20.15, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:GND, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},
    // /OE(1)=U20./Y0  CLK(11)=GND(never writes)  D(2-9)=ALU_R  Q(12-19)=IBUS

    U2:{type:74HC574, function:"r1 (return value / accumulator)",
        1:U20.14, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.15, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    U3:{type:74HC574, function:"r2 (argument 1)",
        1:U20.13, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.14, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    U4:{type:74HC574, function:"r3 (temp 0)",
        1:U20.12, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.13, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    U5:{type:74HC574, function:"r4 (temp 1)",
        1:U20.11, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.12, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    U6:{type:74HC574, function:"r5 (saved 0)",
        1:U20.10, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.11, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    U7:{type:74HC574, function:"r6 (saved 1 / page register)",
        1:U20.9, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.10, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    U8:{type:74HC574, function:"r7 (stack pointer)",
        1:U20.7, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:U21.9, 12:IBUS0, 13:IBUS1, 14:IBUS2, 15:IBUS3,
        16:IBUS4, 17:IBUS5, 18:IBUS6, 19:IBUS7, 20:VCC},

    // ═══════════════════════════════════════════
    // IR + ALU LATCHES — 74HC574 ×3 (U9-U11)
    // ═══════════════════════════════════════════

    U9:{type:74HC574, function:"IR opcode (always outputs to decode)",
        1:GND, 2:IBUS0, 3:IBUS1, 4:IBUS2, 5:IBUS3,
        6:IBUS4, 7:IBUS5, 8:IBUS6, 9:IBUS7, 10:GND,
        11:IR_CLK, 12:OP0, 13:OP1, 14:OP2, 15:OP3,
        16:OP4, 17:OP5, 18:OP6, 19:OP7, 20:VCC},
    // /OE(1)=GND (always on)  CLK(11)=IR_CLK  D←IBUS  Q→Flash addr + decode

    U10:{type:74HC574, function:"IR operand (also drives ALUB for immediate ops)",
        1:OPR_OE, 2:IBUS0, 3:IBUS1, 4:IBUS2, 5:IBUS3,
        6:IBUS4, 7:IBUS5, 8:IBUS6, 9:IBUS7, 10:GND,
        11:OPR_CLK, 12:ALUB0, 13:ALUB1, 14:ALUB2, 15:ALUB3,
        16:ALUB4, 17:ALUB5, 18:ALUB6, 19:ALUB7, 20:VCC},
    // /OE(1)=OPR_OE (LOW for immediate ALU, HIGH when U11 drives ALUB)
    // Q→ALUB shared wire (only one of U10/U11 active at a time)

    U11:{type:74HC574, function:"ALU B latch (holds rs value for reg-reg ops)",
        1:ALUB_OE, 2:IBUS0, 3:IBUS1, 4:IBUS2, 5:IBUS3,
        6:IBUS4, 7:IBUS5, 8:IBUS6, 9:IBUS7, 10:GND,
        11:ALUB_CLK, 12:ALUB0, 13:ALUB1, 14:ALUB2, 15:ALUB3,
        16:ALUB4, 17:ALUB5, 18:ALUB6, 19:ALUB7, 20:VCC},
    // /OE(1)=ALUB_OE (LOW for reg-reg ALU, HIGH when U10 drives ALUB)
    // D←IBUS (rs value loaded in previous step)  Q→ALUB shared wire

    // ═══════════════════════════════════════════
    // ALU — 74HC283 ×2 + 74HC86 ×2 (U12-U15)
    // A input: from IBUS (rd currently driving bus)
    // B input: from ALUB (via XOR for SUB invert)
    // Result: → U25 (result latch) → ALU_R bus → register D inputs
    // ═══════════════════════════════════════════

    U12:{type:74HC283, function:"ALU adder low nibble (bits 3:0)",
        1:ALU_S1, 2:XOR1, 3:IBUS1, 4:ALU_S0,
        5:IBUS0, 6:XOR0, 7:ALU_SUB, 8:GND,
        9:U13.7, 10:ALU_S3, 11:XOR3, 12:IBUS3,
        13:ALU_S2, 14:IBUS2, 15:XOR2, 16:VCC},
    // A1(5)=IBUS0, A2(3)=IBUS1, A3(14)=IBUS2, A4(12)=IBUS3
    // B1(6)=XOR0, B2(2)=XOR1, B3(15)=XOR2, B4(11)=XOR3
    // C0(7)=ALU_SUB (1 for SUB, 0 for ADD)
    // S1(4)→ALU_S0, S2(1)→ALU_S1, S3(13)→ALU_S2, S4(10)→ALU_S3
    // C4(9)→U13.C0

    U13:{type:74HC283, function:"ALU adder high nibble (bits 7:4)",
        1:ALU_S5, 2:XOR5, 3:IBUS5, 4:ALU_S4,
        5:IBUS4, 6:XOR4, 7:U12.9, 8:GND,
        9:CARRY_OUT, 10:ALU_S7, 11:XOR7, 12:IBUS7,
        13:ALU_S6, 14:IBUS6, 15:XOR6, 16:VCC},
    // Same pattern as U12 but for bits 4-7
    // C4(9)=CARRY_OUT → U24 flag_c input

    U14:{type:74HC86, function:"XOR low nibble (SUB invert bits 0-3)",
        1:ALUB0, 2:ALU_SUB, 3:XOR0,
        4:ALUB1, 5:ALU_SUB, 6:XOR1,
        7:GND,
        8:XOR2, 9:ALUB2, 10:ALU_SUB,
        11:XOR3, 12:ALUB3, 13:ALU_SUB, 14:VCC},
    // Gate1: ALUB0 XOR SUB → XOR0 → U12.B1
    // Gate2: ALUB1 XOR SUB → XOR1 → U12.B2
    // Gate3: ALUB2 XOR SUB → XOR2 → U12.B3
    // Gate4: ALUB3 XOR SUB → XOR3 → U12.B4

    U15:{type:74HC86, function:"XOR high nibble (SUB invert bits 4-7)",
        1:ALUB4, 2:ALU_SUB, 3:XOR4,
        4:ALUB5, 5:ALU_SUB, 6:XOR5,
        7:GND,
        8:XOR6, 9:ALUB6, 10:ALU_SUB,
        11:XOR7, 12:ALUB7, 13:ALU_SUB, 14:VCC},

    // ═══════════════════════════════════════════
    // PC — 74HC574 ×2 (U16-U17) — has /OE!
    // Loaded from ALU_R (PC+1 computed by ALU during fetch)
    // Drives ADDR[15:0] during fetch (/OE=LOW)
    // Disconnected during data access (/OE=HIGH)
    // ═══════════════════════════════════════════

    U16:{type:74HC574, function:"PC low byte (drives ADDR[7:0] during fetch)",
        1:DATA_MODE, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:PC_LO_CLK, 12:ADDR0, 13:ADDR1, 14:ADDR2, 15:ADDR3,
        16:ADDR4, 17:ADDR5, 18:ADDR6, 19:ADDR7, 20:VCC},
    // /OE(1)=DATA_MODE (HIGH during data access → PC disconnected)
    // D←ALU_R (PC+1 or branch target)  Q→ADDR[7:0]

    U17:{type:74HC574, function:"PC high byte (drives ADDR[15:8] during fetch)",
        1:DATA_MODE, 2:ALU_R0, 3:ALU_R1, 4:ALU_R2, 5:ALU_R3,
        6:ALU_R4, 7:ALU_R5, 8:ALU_R6, 9:ALU_R7, 10:GND,
        11:PC_HI_CLK, 12:ADDR8, 13:ADDR9, 14:ADDR10, 15:ADDR11,
        16:ADDR12, 17:ADDR13, 18:ADDR14, 19:ADDR15, 20:VCC},

    // ═══════════════════════════════════════════
    // ADDRESS LATCHES — 74HC574 ×2 (U18-U19)
    // Loaded from IBUS during address setup steps
    // Drive ADDR[15:0] during data access (/OE=LOW)
    // Disconnected during fetch (/OE=HIGH)
    // ═══════════════════════════════════════════

    U18:{type:74HC574, function:"Address latch low (drives ADDR[7:0] during data)",
        1:/DATA_MODE, 2:IBUS0, 3:IBUS1, 4:IBUS2, 5:IBUS3,
        6:IBUS4, 7:IBUS5, 8:IBUS6, 9:IBUS7, 10:GND,
        11:ADDR_LO_CLK, 12:ADDR0, 13:ADDR1, 14:ADDR2, 15:ADDR3,
        16:ADDR4, 17:ADDR5, 18:ADDR6, 19:ADDR7, 20:VCC},
    // /OE(1)=/DATA_MODE = NOT(DATA_MODE) — use spare XOR as inverter
    // D←IBUS (register value for address)  Q→ADDR[7:0]

    U19:{type:74HC574, function:"Address latch high (drives ADDR[15:8] during data)",
        1:/DATA_MODE, 2:IBUS0, 3:IBUS1, 4:IBUS2, 5:IBUS3,
        6:IBUS4, 7:IBUS5, 8:IBUS6, 9:IBUS7, 10:GND,
        11:ADDR_HI_CLK, 12:ADDR8, 13:ADDR9, 14:ADDR10, 15:ADDR11,
        16:ADDR12, 17:ADDR13, 18:ADDR14, 19:ADDR15, 20:VCC},

    // ═══════════════════════════════════════════
    // DECODE — 74HC138 ×2 (U20-U21)
    // ═══════════════════════════════════════════

    U20:{type:74HC138, function:"Register READ select (who drives IBUS)",
        1:REG_RD0, 2:REG_RD1, 3:REG_RD2, 4:GND,
        5:GND, 6:VCC, 7:U8./OE, 8:GND,
        9:U7./OE, 10:U6./OE, 11:U5./OE, 12:U4./OE,
        13:U3./OE, 14:U2./OE, 15:U1./OE, 16:VCC},
    // A,B,C from microcode (REG_RD[2:0])
    // /Y0→U1./OE, /Y1→U2./OE, ... /Y7→U8./OE

    U21:{type:74HC138, function:"Register WRITE select (who latches ALU_R)",
        1:REG_WR0, 2:REG_WR1, 3:REG_WR2, 4:GND,
        5:GND, 6:REG_WR_EN, 7:U8.CLK, 8:GND,
        9:U7.CLK, 10:U6.CLK, 11:U5.CLK, 12:U4.CLK,
        13:U3.CLK, 14:U2.CLK, 15:U1.CLK, 16:VCC},
    // G1=REG_WR_EN (from microcode, only pulses on write step)
    // /Y0→U1.CLK(tied GND anyway), /Y1→U2.CLK, ... /Y7→U8.CLK

    // ═══════════════════════════════════════════
    // BUS BUFFER — 74HC245 (U22)
    // ═══════════════════════════════════════════

    U22:{type:74HC245, function:"External bus buffer (IBUS ↔ ROM/RAM data)",
        1:BUF_DIR, 2:IBUS0, 3:IBUS1, 4:IBUS2, 5:IBUS3,
        6:IBUS4, 7:IBUS5, 8:IBUS6, 9:IBUS7, 10:GND,
        11:DEXT7, 12:DEXT6, 13:DEXT5, 14:DEXT4, 15:DEXT3,
        16:DEXT2, 17:DEXT1, 18:DEXT0, 19:BUF_OE, 20:VCC},
    // DIR(1): 0=B→A(read ext→IBUS), 1=A→B(write IBUS→ext)
    // /OE(19): LOW=enabled (only during memory access steps)

    // ═══════════════════════════════════════════
    // MICROCODE FLASH — SST39SF010A (U23, PDIP-32, 70ns)
    // ═══════════════════════════════════════════

    U23:{type:SST39SF010A, function:"Microcode control ROM",
        // Address = {/IRQ, step[2:0], opcode[7:0], flag_z, flag_c} = 14 bits
        // Data = 8 control signal outputs
        10:OP0, 9:OP1, 8:OP2, 7:OP3, 6:OP4, 5:OP5, 4:OP6, 3:OP7,
        25:STEP0, 24:STEP1, 21:STEP2,
        23:FLAG_Z, 26:FLAG_C,
        1:/IRQ, 2:GND, 14:GND, 20:GND, 22:GND, 30:GND,
        27:VCC, 28:VCC, 31:VCC, 32:VCC,
        11:CTRL0, 12:CTRL1, 13:CTRL2, 15:CTRL3,
        16:CTRL4, 17:CTRL5, 18:CTRL6, 19:CTRL7},
    // A13(pin 1) = /IRQ from bus pin 30 (active low)
    // When /IRQ=LOW: microcode enters interrupt sequence at step 0
    // When /IRQ=HIGH: normal execution
    // Flash table: 16K entries (14 address bits) × 8 data bits = 16KB used of 128KB
    // Interrupt sequence (in microcode): push PC, load vector, jump to handler

    // ═══════════════════════════════════════════
    // FLAGS — 74HC74 (U24)
    // ═══════════════════════════════════════════

    U24:{type:74HC74, function:"Flags: Z (zero) and C (carry)",
        1:/RST, 2:ALU_ZERO, 3:FLAGS_CLK, 4:VCC,
        5:FLAG_Z, 6:, 7:GND, 8:,
        9:FLAG_C, 10:VCC, 11:FLAGS_CLK, 12:CARRY_OUT,
        13:/RST, 14:VCC},
    // FF1: D=ALU_ZERO (NOR of all ALU_S bits), Q=FLAG_Z → Flash addr
    // FF2: D=CARRY_OUT (U13.9), Q=FLAG_C → Flash addr

    // ═══════════════════════════════════════════
    // ALU RESULT LATCH — 74HC574 (U25)
    // ═══════════════════════════════════════════

    U25:{type:74HC574, function:"ALU result latch → ALU_R bus → all register D inputs",
        1:GND, 2:ALU_S0, 3:ALU_S1, 4:ALU_S2, 5:ALU_S3,
        6:ALU_S4, 7:ALU_S5, 8:ALU_S6, 9:ALU_S7, 10:GND,
        11:ALUR_CLK, 12:ALU_R0, 13:ALU_R1, 14:ALU_R2, 15:ALU_R3,
        16:ALU_R4, 17:ALU_R5, 18:ALU_R6, 19:ALU_R7, 20:VCC},
    // /OE(1)=GND (always drives ALU_R bus)
    // D←adder outputs (ALU_S), Q→ALU_R→all register D inputs + PC D inputs

    // ═══════════════════════════════════════════
    // MEMORY — ROM + RAM
    // ═══════════════════════════════════════════

    ROM:{type:AT28C256, function:"Program ROM (32KB)",
        1:ADDR14, 2:ADDR12, 3:ADDR7, 4:ADDR6, 5:ADDR5, 6:ADDR4,
        7:ADDR3, 8:ADDR2, 9:ADDR1, 10:ADDR0, 11:DEXT0, 12:DEXT1,
        13:DEXT2, 14:GND, 15:DEXT3, 16:DEXT4, 17:DEXT5, 18:DEXT6,
        19:DEXT7, 20:ADDR15, 21:ADDR10, 22:/RD, 23:ADDR11,
        24:ADDR9, 25:ADDR8, 26:ADDR13, 27:VCC, 28:VCC},
    // /CE(20)=ADDR15 inverted (active when A15=0... or tie to decode)
    // /OE(22)=/RD, /WE(27)=VCC

    RAM:{type:62256, function:"Data RAM (32KB)",
        1:ADDR14, 2:ADDR12, 3:ADDR7, 4:ADDR6, 5:ADDR5, 6:ADDR4,
        7:ADDR3, 8:ADDR2, 9:ADDR1, 10:ADDR0, 11:DEXT0, 12:DEXT1,
        13:DEXT2, 14:GND, 15:DEXT3, 16:DEXT4, 17:DEXT5, 18:DEXT6,
        19:DEXT7, 20:ADDR15, 21:ADDR10, 22:/RD, 23:ADDR11,
        24:ADDR9, 25:ADDR8, 26:ADDR13, 27:/WR, 28:VCC},

    // ═══════════════════════════════════════════
    // SUPPORT
    // ═══════════════════════════════════════════

    OSC:{type:"Crystal 3.5MHz/10MHz (4-pin DIP)", 1:VCC, 7:GND, 8:CLK, 14:},
    R1:{type:"10K", function:"Reset pull-up", 1:VCC, 2:/RST},
    SW_RST:{type:"Pushbutton", function:"Reset", 1:/RST, 2:GND},
    C1:{type:"100nF", function:"Reset debounce", 1:/RST, 2:GND},
    C2:{type:"100nF", function:"Decoupling Flash", 1:VCC, 2:GND},
    C3:{type:"100nF", function:"Decoupling ROM", 1:VCC, 2:GND},
    C4:{type:"100nF", function:"Decoupling RAM", 1:VCC, 2:GND},
    C5:{type:"100uF", function:"Bulk power", 1:VCC, 2:GND},

    // === LEDs (optional debug) ===
    LED_D0:{A:IBUS0, K:R330.GND}, LED_D1:{A:IBUS1, K:R330.GND},
    LED_D2:{A:IBUS2, K:R330.GND}, LED_D3:{A:IBUS3, K:R330.GND},
    LED_D4:{A:IBUS4, K:R330.GND}, LED_D5:{A:IBUS5, K:R330.GND},
    LED_D6:{A:IBUS6, K:R330.GND}, LED_D7:{A:IBUS7, K:R330.GND},
    LED_CLK:{A:CLK, K:R330.GND},

    // === 40-PIN BUS CONNECTOR ===
    RV8_Bus:{type:"40-pin IDC",
        1:ADDR0, 2:ADDR1, 3:ADDR2, 4:ADDR3,
        5:ADDR4, 6:ADDR5, 7:ADDR6, 8:ADDR7,
        9:ADDR8, 10:ADDR9, 11:ADDR10, 12:ADDR11,
        13:ADDR12, 14:ADDR13, 15:ADDR14, 16:ADDR15,
        17:DEXT0, 18:DEXT1, 19:DEXT2, 20:DEXT3,
        21:DEXT4, 22:DEXT5, 23:DEXT6, 24:DEXT7,
        25:/RD, 26:/WR, 27:CLK, 28:/RST,
        29:/NMI, 30:/IRQ, 31:HALT, 32:SYNC,
        33:, 34:, 35:, 36:,
        37:, 38:, 39:VCC, 40:GND}

    // ═══════════════════════════════════════════
    // POWER TABLE
    // ═══════════════════════════════════════════
    // U1-U11, U16-U19, U25 (74HC574): VCC=20, GND=10
    // U12-U13 (74HC283): VCC=16, GND=8
    // U14-U15 (74HC86): VCC=14, GND=7
    // U20-U21 (74HC138): VCC=16, GND=8
    // U22 (74HC245): VCC=20, GND=10
    // U23 (SST39SF010A): VCC=32, GND=16
    // U24 (74HC74): VCC=14, GND=7
    // ROM (AT28C256): VCC=28, GND=14
    // RAM (62256): VCC=28, GND=14
    }
}
