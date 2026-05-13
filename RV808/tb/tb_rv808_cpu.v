`timescale 1ns / 1ps
module tb_rv808_cpu;

reg clk, rst_n, nmi_n, irq_n;
wire [14:0] code_addr;
wire [7:0]  code_data;
wire [15:0] data_addr;
wire [7:0]  data_out;
reg  [7:0]  data_in;
wire        data_rd, data_wr, pg_wr;

// Code ROM (32KB)
reg [7:0] rom [0:32767];
assign code_data = rom[code_addr];

// Data RAM (32KB)
reg [7:0] ram [0:32767];

// Data bus handling
always @(*) begin
    data_in = ram[data_addr[14:0]];
end
always @(posedge clk) begin
    if (data_wr)
        ram[data_addr[14:0]] <= data_out;
end

rv808_cpu uut (
    .clk(clk), .rst_n(rst_n), .nmi_n(nmi_n), .irq_n(irq_n),
    .code_addr(code_addr), .code_data(code_data),
    .data_addr(data_addr), .data_out(data_out), .data_in(data_in),
    .data_rd(data_rd), .data_wr(data_wr), .pg_wr(pg_wr)
);

// Clock
initial clk = 0;
always #5 clk = ~clk;

integer pass_count = 0;
integer fail_count = 0;
integer test_num = 0;

task run(input integer cycles);
    integer i;
    begin
    for (i = 0; i < cycles; i = i + 1)
        @(posedge clk);
    end
endtask

task check(input [7:0] got, input [7:0] expected, input [255:0] name);
    begin
    test_num = test_num + 1;
    if (got === expected) begin
        pass_count = pass_count + 1;
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL #%0d: %0s — got $%02X, expected $%02X", test_num, name, got, expected);
    end
    end
endtask

task check_flag(input got, input expected, input [255:0] name);
    begin
    test_num = test_num + 1;
    if (got === expected) begin
        pass_count = pass_count + 1;
    end else begin
        fail_count = fail_count + 1;
        $display("FAIL #%0d: %0s — got %0b, expected %0b", test_num, name, got, expected);
    end
    end
endtask

task load_program;
    integer i;
    begin
    for (i = 0; i < 32768; i = i + 1) rom[i] = 8'h00;
    for (i = 0; i < 32768; i = i + 1) ram[i] = 8'h00;
    end
endtask

// Opcodes
localparam LI_A0  = 8'hA0;
localparam LI_T0  = 8'hA1;
localparam LI_SP  = 8'hA2;
localparam PAGE   = 8'hA3;
localparam ADDI   = 8'h20;
localparam SUBI   = 8'h21;
localparam CMPI   = 8'h22;
localparam ANDI   = 8'h23;
localparam ORI    = 8'h24;
localparam XORI   = 8'h25;
localparam TST    = 8'h26;
localparam ADD_T0 = 8'h00;
localparam SUB_T0 = 8'h01;
localparam AND_T0 = 8'h02;
localparam OR_T0  = 8'h03;
localparam XOR_T0 = 8'h04;
localparam CMP_T0 = 8'h05;
localparam ADC_T0 = 8'h06;
localparam SBC_T0 = 8'h07;
localparam LB_PG  = 8'h40;
localparam SB_PG  = 8'h44;
localparam LB_PT0 = 8'h48;
localparam SB_PT0 = 8'h4C;
localparam LB_ZP  = 8'h50;
localparam SB_ZP  = 8'h54;
localparam LB_SP  = 8'h58;
localparam SB_SP  = 8'h5C;
localparam BEQ    = 8'h60;
localparam BNE    = 8'h61;
localparam BCS    = 8'h62;
localparam BCC    = 8'h63;
localparam BMI    = 8'h64;
localparam BPL    = 8'h65;
localparam BRA    = 8'h66;
localparam SHL    = 8'h80;
localparam SHR    = 8'h81;
localparam ROL    = 8'h82;
localparam ROR    = 8'h83;
localparam INC    = 8'h84;
localparam DEC    = 8'h85;
localparam NOT_OP = 8'h86;
localparam SWAP   = 8'h87;
localparam PUSH_A = 8'hC0;
localparam PUSH_T = 8'hC1;
localparam POP_A  = 8'hC2;
localparam POP_T  = 8'hC3;
localparam JAL    = 8'hC4;
localparam RET    = 8'hC5;
localparam NOP    = 8'hE0;
localparam HLT    = 8'hE1;
localparam EI     = 8'hE2;
localparam DI     = 8'hE3;
localparam CLC    = 8'hE4;
localparam SEC    = 8'hE5;
localparam TRAP   = 8'hE6;
localparam RTI    = 8'hE7;
localparam SKIPZ  = 8'hE8;
localparam SKIPNZ = 8'hE9;
localparam SKIPC  = 8'hEA;
localparam SKIPNC = 8'hEB;

initial begin
    $dumpfile("rv808.vcd");
    $dumpvars(0, tb_rv808_cpu);

    load_program;
    rst_n = 0; nmi_n = 1; irq_n = 1;
    #20 rst_n = 1;

    // ===== TEST: LI a0 =====
    rom[0] = LI_A0; rom[1] = 8'h42;
    rom[2] = HLT;   rom[3] = 8'h00;
    run(10);
    check(uut.a0, 8'h42, "LI a0, $42");

    // ===== TEST: LI t0 =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_T0; rom[1] = 8'hAB;
    rom[2] = HLT;   rom[3] = 8'h00;
    run(10);
    check(uut.t0, 8'hAB, "LI t0, $AB");

    // ===== TEST: LI sp =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_SP; rom[1] = 8'hFF;
    rom[2] = HLT;   rom[3] = 8'h00;
    run(10);
    check(uut.sp, 8'hFF, "LI sp, $FF");

    // ===== TEST: PAGE =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = PAGE;  rom[1] = 8'h08;
    rom[2] = HLT;   rom[3] = 8'h00;
    run(10);
    check(uut.pg, 8'h08, "PAGE $08");

    // ===== TEST: ADDI =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h10;
    rom[2] = ADDI;  rom[3] = 8'h05;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check(uut.a0, 8'h15, "ADDI $05");

    // ===== TEST: SUBI =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h20;
    rom[2] = SUBI;  rom[3] = 8'h08;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check(uut.a0, 8'h18, "SUBI $08");

    // ===== TEST: ANDI =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'hF5;
    rom[2] = ANDI;  rom[3] = 8'h0F;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check(uut.a0, 8'h05, "ANDI $0F");

    // ===== TEST: ORI =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'hA0;
    rom[2] = ORI;   rom[3] = 8'h05;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check(uut.a0, 8'hA5, "ORI $05");

    // ===== TEST: XORI =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'hFF;
    rom[2] = XORI;  rom[3] = 8'h0F;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check(uut.a0, 8'hF0, "XORI $0F");

    // ===== TEST: ADD t0 =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h10;
    rom[2] = LI_T0; rom[3] = 8'h20;
    rom[4] = ADD_T0;rom[5] = 8'h00;
    rom[6] = HLT;   rom[7] = 8'h00;
    run(15);
    check(uut.a0, 8'h30, "ADD t0");

    // ===== TEST: SUB t0 =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h30;
    rom[2] = LI_T0; rom[3] = 8'h10;
    rom[4] = SUB_T0;rom[5] = 8'h00;
    rom[6] = HLT;   rom[7] = 8'h00;
    run(15);
    check(uut.a0, 8'h20, "SUB t0");

    // ===== TEST: SB/LB pg:imm =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h99;
    rom[2] = PAGE;  rom[3] = 8'h02;
    rom[4] = SB_PG; rom[5] = 8'h10;  // store a0 to {$02,$10}
    rom[6] = LI_A0; rom[7] = 8'h00;  // clear a0
    rom[8] = LB_PG; rom[9] = 8'h10;  // load back
    rom[10]= HLT;   rom[11]= 8'h00;
    run(25);
    check(uut.a0, 8'h99, "SB/LB pg:imm");

    // ===== TEST: SB/LB zp:imm =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h77;
    rom[2] = SB_ZP; rom[3] = 8'h42;  // store to {$00,$42}
    rom[4] = LI_A0; rom[5] = 8'h00;
    rom[6] = LB_ZP; rom[7] = 8'h42;  // load back
    rom[8] = HLT;   rom[9] = 8'h00;
    run(22);
    check(uut.a0, 8'h77, "SB/LB zp:imm");

    // ===== TEST: SB/LB pg:t0 =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'hBB;
    rom[2] = PAGE;  rom[3] = 8'h03;
    rom[4] = LI_T0; rom[5] = 8'h20;
    rom[6] = SB_PT0;rom[7] = 8'h00;  // store to {$03, t0=$20}
    rom[8] = LI_A0; rom[9] = 8'h00;
    rom[10]= LB_PT0;rom[11]= 8'h00;  // load back
    rom[12]= HLT;   rom[13]= 8'h00;
    run(30);
    check(uut.a0, 8'hBB, "SB/LB pg:t0");

    // ===== TEST: SHL =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h41;
    rom[2] = SHL;   rom[3] = 8'h00;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check(uut.a0, 8'h82, "SHL");

    // ===== TEST: SHR =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h82;
    rom[2] = SHR;   rom[3] = 8'h00;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check(uut.a0, 8'h41, "SHR");

    // ===== TEST: INC =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h0F;
    rom[2] = INC;   rom[3] = 8'h00;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check(uut.a0, 8'h10, "INC");

    // ===== TEST: DEC =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h10;
    rom[2] = DEC;   rom[3] = 8'h00;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check(uut.a0, 8'h0F, "DEC");

    // ===== TEST: NOT =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'hA5;
    rom[2] = NOT_OP;rom[3] = 8'h00;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check(uut.a0, 8'h5A, "NOT");

    // ===== TEST: SWAP =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'hAB;
    rom[2] = SWAP;  rom[3] = 8'h00;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check(uut.a0, 8'hBA, "SWAP");

    // ===== TEST: BEQ taken =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h00;  // Z=1
    rom[2] = BEQ;   rom[3] = 8'h02;  // skip 2 bytes forward
    rom[4] = LI_A0; rom[5] = 8'hFF;  // should be skipped
    rom[6] = LI_A0; rom[7] = 8'h42;  // land here
    rom[8] = HLT;   rom[9] = 8'h00;
    run(15);
    check(uut.a0, 8'h42, "BEQ taken");

    // ===== TEST: BNE not taken =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h00;  // Z=1
    rom[2] = BNE;   rom[3] = 8'h02;  // not taken (Z=1)
    rom[4] = LI_A0; rom[5] = 8'h33;  // executes
    rom[6] = HLT;   rom[7] = 8'h00;
    run(15);
    check(uut.a0, 8'h33, "BNE not taken");

    // ===== TEST: PUSH/POP a0 =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_SP; rom[1] = 8'hFF;
    rom[2] = LI_A0; rom[3] = 8'h55;
    rom[4] = PUSH_A;rom[5] = 8'h00;
    rom[6] = LI_A0; rom[7] = 8'h00;  // clear
    rom[8] = POP_A; rom[9] = 8'h00;
    rom[10]= HLT;   rom[11]= 8'h00;
    run(25);
    check(uut.a0, 8'h55, "PUSH/POP a0");

    // ===== TEST: PUSH/POP t0 =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_SP; rom[1] = 8'hFF;
    rom[2] = LI_T0; rom[3] = 8'hAA;
    rom[4] = PUSH_T;rom[5] = 8'h00;
    rom[6] = LI_T0; rom[7] = 8'h00;
    rom[8] = POP_T; rom[9] = 8'h00;
    rom[10]= HLT;   rom[11]= 8'h00;
    run(25);
    check(uut.t0, 8'hAA, "PUSH/POP t0");

    // ===== TEST: SKIPZ =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h00;  // Z=1
    rom[2] = SKIPZ; rom[3] = 8'h00;
    rom[4] = LI_A0; rom[5] = 8'hFF;  // skipped
    rom[6] = LI_A0; rom[7] = 8'h42;  // executes
    rom[8] = HLT;   rom[9] = 8'h00;
    run(20);
    check(uut.a0, 8'h42, "SKIPZ");

    // ===== TEST: SKIPNZ =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h01;  // Z=0
    rom[2] = SKIPNZ;rom[3] = 8'h00;
    rom[4] = LI_A0; rom[5] = 8'hFF;  // skipped
    rom[6] = LI_A0; rom[7] = 8'h33;  // executes
    rom[8] = HLT;   rom[9] = 8'h00;
    run(20);
    check(uut.a0, 8'h33, "SKIPNZ");

    // ===== TEST: CLC/SEC =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = SEC;   rom[1] = 8'h00;
    rom[2] = HLT;   rom[3] = 8'h00;
    run(10);
    check_flag(uut.flag_c, 1'b1, "SEC");

    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = SEC;   rom[1] = 8'h00;
    rom[2] = CLC;   rom[3] = 8'h00;
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check_flag(uut.flag_c, 1'b0, "CLC");

    // ===== TEST: Z flag =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h01;
    rom[2] = SUBI;  rom[3] = 8'h01;  // a0=0, Z=1
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check_flag(uut.flag_z, 1'b1, "Z flag set");
    check(uut.a0, 8'h00, "SUBI result 0");

    // ===== TEST: N flag =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_A0; rom[1] = 8'h00;
    rom[2] = SUBI;  rom[3] = 8'h01;  // a0=$FF, N=1
    rom[4] = HLT;   rom[5] = 8'h00;
    run(12);
    check_flag(uut.flag_n, 1'b1, "N flag set");
    check(uut.a0, 8'hFF, "SUBI underflow");

    // ===== TEST: SP+imm addressing =====
    load_program; rst_n=0; #20 rst_n=1;
    rom[0] = LI_SP; rom[1] = 8'h80;
    rom[2] = LI_A0; rom[3] = 8'hDD;
    rom[4] = SB_SP; rom[5] = 8'h04;  // store to {$01, $80+$04=$84}
    rom[6] = LI_A0; rom[7] = 8'h00;
    rom[8] = LB_SP; rom[9] = 8'h04;  // load back
    rom[10]= HLT;   rom[11]= 8'h00;
    run(25);
    check(uut.a0, 8'hDD, "LB/SB sp+imm");

    // ===== RESULTS =====
    $display("");
    $display("========================================");
    $display("  RV808 Testbench Results");
    $display("  PASS: %0d / %0d", pass_count, test_num);
    if (fail_count > 0)
        $display("  FAIL: %0d", fail_count);
    else
        $display("  ALL TESTS PASSED!");
    $display("========================================");
    $finish;
end

endmodule
