`timescale 1ns / 1ps
module tb_rv8g_cpu;

reg clk, rst_n, nmi_n, irq_n;
wire [15:0] addr;
wire [7:0]  data_out;
reg  [7:0]  data_in;
wire        mem_rd, mem_wr;

// Unified memory (64KB)
reg [7:0] mem [0:65535];

always @(*) data_in = mem[addr];
always @(posedge clk) if (mem_wr) mem[addr] <= data_out;

rv8g_cpu uut (.clk(clk), .rst_n(rst_n), .nmi_n(nmi_n), .irq_n(irq_n),
    .addr(addr), .data_out(data_out), .data_in(data_in),
    .mem_rd(mem_rd), .mem_wr(mem_wr));

initial clk = 0;
always #5 clk = ~clk;

integer pass_count = 0, fail_count = 0, test_num = 0;

task run(input integer cycles);
    integer i;
    begin
    for (i = 0; i < cycles; i = i + 1) @(posedge clk);
    end
endtask

task check(input [7:0] got, input [7:0] expected, input [255:0] name);
    begin
    test_num = test_num + 1;
    if (got === expected) pass_count = pass_count + 1;
    else begin
        fail_count = fail_count + 1;
        $display("FAIL #%0d: %0s — got $%02X, expected $%02X", test_num, name, got, expected);
    end
    end
endtask

task reset_cpu;
    integer i;
    begin
    for (i = 0; i < 65536; i = i + 1) mem[i] = 8'h00;
    rst_n = 0; #20; rst_n = 1;
    end
endtask

// Opcode encoding helpers
// Class 00: ALU — {00, op[2:0], modf[2:0]}
// Class 01: LDST — {01, op[2:0], modf[2:0]}
// Class 10: Branch — {10, cond[2:0], xxx}
// Class 11: System — {11, op[2:0], xxx}

// ALU class (00_ooo_m): op=operation, m[0]=0:reg, 1:imm
localparam ADD_T  = 8'b00_000_000;
localparam SUB_T  = 8'b00_001_000;
localparam AND_T  = 8'b00_010_000;
localparam OR_T   = 8'b00_011_000;
localparam XOR_T  = 8'b00_100_000;
localparam CMP_T  = 8'b00_101_000;
localparam INC_A  = 8'b00_110_000;
localparam DEC_A  = 8'b00_111_000;
localparam ADDI   = 8'b00_000_001;
localparam SUBI   = 8'b00_001_001;
localparam ANDI   = 8'b00_010_001;
localparam ORI    = 8'b00_011_001;
localparam XORI   = 8'b00_100_001;
localparam CMPI   = 8'b00_101_001;
localparam MOV_TA = 8'b00_111_001; // MOV t0←a0 (op=7, imm=1 → special)

// LDST class (01_ooo_rrr)
localparam LI_A0  = 8'b01_000_000;
localparam LI_T0  = 8'b01_000_001;
localparam LI_SP  = 8'b01_000_010;
localparam LI_PL  = 8'b01_000_011;
localparam LI_PH  = 8'b01_000_100;
localparam LB_PTR = 8'b01_001_000;
localparam SB_PTR = 8'b01_010_000;
localparam LB_ZP  = 8'b01_011_000;
localparam SB_ZP  = 8'b01_100_000;
localparam LB_PTR_INC = 8'b01_101_000;

// Branch class (10_ccc_xxx)
localparam BEQ    = 8'b10_000_000;
localparam BNE    = 8'b10_001_000;
localparam BRA    = 8'b10_110_000;
localparam JMP    = 8'b10_111_000;

// System class (11_ooo_xxx)
localparam PUSH_A = 8'b11_000_000;
localparam POP_A  = 8'b11_001_000;
localparam CALL   = 8'b11_010_000;
localparam RET    = 8'b11_011_000;
localparam NOP    = 8'b11_100_000;
localparam HLT    = 8'b11_101_000;

initial begin
    $dumpfile("rv8g.vcd");
    $dumpvars(0, tb_rv8g_cpu);
    nmi_n = 1; irq_n = 1;

    // ===== LI a0 =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'h42;
    mem[16'hC002] = HLT;   mem[16'hC003] = 8'h00;
    run(16);
    check(uut.a0, 8'h42, "LI a0, $42");

    // ===== LI t0 =====
    reset_cpu;
    mem[16'hC000] = LI_T0; mem[16'hC001] = 8'hAB;
    mem[16'hC002] = HLT;   mem[16'hC003] = 8'h00;
    run(16);
    check(uut.t0, 8'hAB, "LI t0, $AB");

    // ===== ADDI =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'h10;
    mem[16'hC002] = ADDI;  mem[16'hC003] = 8'h05;
    mem[16'hC004] = HLT;   mem[16'hC005] = 8'h00;
    run(20);
    check(uut.a0, 8'h15, "ADDI $05");

    // ===== SUBI =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'h20;
    mem[16'hC002] = SUBI;  mem[16'hC003] = 8'h08;
    mem[16'hC004] = HLT;   mem[16'hC005] = 8'h00;
    run(20);
    check(uut.a0, 8'h18, "SUBI $08");

    // ===== ADD t0 =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'h10;
    mem[16'hC002] = LI_T0; mem[16'hC003] = 8'h20;
    mem[16'hC004] = ADD_T; mem[16'hC005] = 8'h00;
    mem[16'hC006] = HLT;   mem[16'hC007] = 8'h00;
    run(24);
    check(uut.a0, 8'h30, "ADD t0");

    // ===== SUB t0 =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'h30;
    mem[16'hC002] = LI_T0; mem[16'hC003] = 8'h10;
    mem[16'hC004] = SUB_T; mem[16'hC005] = 8'h00;
    mem[16'hC006] = HLT;   mem[16'hC007] = 8'h00;
    run(24);
    check(uut.a0, 8'h20, "SUB t0");

    // ===== ANDI =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'hF5;
    mem[16'hC002] = ANDI;  mem[16'hC003] = 8'h0F;
    mem[16'hC004] = HLT;   mem[16'hC005] = 8'h00;
    run(20);
    check(uut.a0, 8'h05, "ANDI $0F");

    // ===== ORI =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'hA0;
    mem[16'hC002] = ORI;   mem[16'hC003] = 8'h05;
    mem[16'hC004] = HLT;   mem[16'hC005] = 8'h00;
    run(20);
    check(uut.a0, 8'hA5, "ORI $05");

    // ===== INC =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'h0F;
    mem[16'hC002] = INC_A; mem[16'hC003] = 8'h00;
    mem[16'hC004] = HLT;   mem[16'hC005] = 8'h00;
    run(20);
    check(uut.a0, 8'h10, "INC");

    // ===== DEC =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'h10;
    mem[16'hC002] = DEC_A; mem[16'hC003] = 8'h00;
    mem[16'hC004] = HLT;   mem[16'hC005] = 8'h00;
    run(20);
    check(uut.a0, 8'h0F, "DEC");

    // ===== SB/LB zero-page =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'h99;
    mem[16'hC002] = SB_ZP; mem[16'hC003] = 8'h42;
    mem[16'hC004] = LI_A0; mem[16'hC005] = 8'h00;
    mem[16'hC006] = LB_ZP; mem[16'hC007] = 8'h42;
    mem[16'hC008] = HLT;   mem[16'hC009] = 8'h00;
    run(40);
    check(uut.a0, 8'h99, "SB/LB zp");

    // ===== SB/LB pointer =====
    reset_cpu;
    mem[16'hC000] = LI_PH; mem[16'hC001] = 8'h00;
    mem[16'hC002] = LI_PL; mem[16'hC003] = 8'h80;
    mem[16'hC004] = LI_A0; mem[16'hC005] = 8'hBB;
    mem[16'hC006] = SB_PTR;mem[16'hC007] = 8'h00;
    mem[16'hC008] = LI_A0; mem[16'hC009] = 8'h00;
    mem[16'hC00A] = LB_PTR;mem[16'hC00B] = 8'h00;
    mem[16'hC00C] = HLT;   mem[16'hC00D] = 8'h00;
    run(50);
    check(uut.a0, 8'hBB, "SB/LB ptr");

    // ===== BEQ taken =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'h00; // Z=1
    mem[16'hC002] = BEQ;   mem[16'hC003] = 8'h02; // skip 2 bytes
    mem[16'hC004] = LI_A0; mem[16'hC005] = 8'hFF; // skipped
    mem[16'hC006] = LI_A0; mem[16'hC007] = 8'h42; // land here
    mem[16'hC008] = HLT;   mem[16'hC009] = 8'h00;
    run(24);
    check(uut.a0, 8'h42, "BEQ taken");

    // ===== BNE not taken =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'h00; // Z=1
    mem[16'hC002] = BNE;   mem[16'hC003] = 8'h02; // not taken
    mem[16'hC004] = LI_A0; mem[16'hC005] = 8'h33; // executes
    mem[16'hC006] = HLT;   mem[16'hC007] = 8'h00;
    run(24);
    check(uut.a0, 8'h33, "BNE not taken");

    // ===== Loop (BNE backward) =====
    reset_cpu;
    mem[16'hC000] = LI_A0; mem[16'hC001] = 8'h00;
    mem[16'hC002] = INC_A; mem[16'hC003] = 8'h00;
    mem[16'hC004] = CMPI;  mem[16'hC005] = 8'h03;
    mem[16'hC006] = BNE;   mem[16'hC007] = 8'hFA; // -6
    mem[16'hC008] = HLT;   mem[16'hC009] = 8'h00;
    run(80);
    check(uut.a0, 8'h03, "Loop BNE backward");

    // ===== PUSH/POP =====
    reset_cpu;
    mem[16'hC000] = LI_SP; mem[16'hC001] = 8'hFF;
    mem[16'hC002] = LI_A0; mem[16'hC003] = 8'h55;
    mem[16'hC004] = PUSH_A;mem[16'hC005] = 8'h00;
    mem[16'hC006] = LI_A0; mem[16'hC007] = 8'h00;
    mem[16'hC008] = POP_A; mem[16'hC009] = 8'h00;
    mem[16'hC00A] = HLT;   mem[16'hC00B] = 8'h00;
    run(44);
    check(uut.a0, 8'h55, "PUSH/POP a0");

    // ===== CALL/RET =====
    reset_cpu;
    mem[16'hC000] = LI_SP; mem[16'hC001] = 8'hFF;
    mem[16'hC002] = LI_PH; mem[16'hC003] = 8'hC0; // ph=$C0
    mem[16'hC004] = CALL;  mem[16'hC005] = 8'h20; // call $C020
    mem[16'hC006] = HLT;   mem[16'hC007] = 8'h00; // return here
    // Subroutine at $C020:
    mem[16'hC020] = LI_A0; mem[16'hC021] = 8'h77;
    mem[16'hC022] = RET;   mem[16'hC023] = 8'h00;
    run(50);
    check(uut.a0, 8'h77, "CALL/RET");

    // ===== ADC (add with carry) =====
    reset_cpu;
    mem[16'hC000] = LI_A0;          mem[16'hC001] = 8'hFF;
    mem[16'hC002] = 8'b00_000_001;  mem[16'hC003] = 8'h01; // ADDI 1 → a0=0, C=1
    mem[16'hC004] = LI_A0;          mem[16'hC005] = 8'h05;
    mem[16'hC006] = 8'b00_000_011;  mem[16'hC007] = 8'h00; // ADCI 0 (add carry) → a0=5+0+1=6
    mem[16'hC008] = HLT;            mem[16'hC009] = 8'h00;
    run(32);
    check(uut.a0, 8'h06, "ADC (carry propagation)");

    // ===== SBC (subtract with borrow) =====
    reset_cpu;
    mem[16'hC000] = LI_A0;          mem[16'hC001] = 8'h00;
    mem[16'hC002] = 8'b00_001_001;  mem[16'hC003] = 8'h01; // SUBI 1 → a0=FF, C=1(borrow)
    mem[16'hC004] = LI_A0;          mem[16'hC005] = 8'h10;
    mem[16'hC006] = 8'b00_001_011;  mem[16'hC007] = 8'h00; // SBCI 0 (sub borrow) → 10-0-1=0F
    mem[16'hC008] = HLT;            mem[16'hC009] = 8'h00;
    run(32);
    check(uut.a0, 8'h0F, "SBC (borrow propagation)");

    // ===== MOV pl, a0 =====
    reset_cpu;
    mem[16'hC000] = LI_A0;          mem[16'hC001] = 8'h42;
    mem[16'hC002] = 8'b01_110_000;  mem[16'hC003] = 8'h00; // MOV pl, a0
    mem[16'hC004] = HLT;            mem[16'hC005] = 8'h00;
    run(20);
    check(uut.pl, 8'h42, "MOV pl, a0");

    // ===== MOV ph, a0 =====
    reset_cpu;
    mem[16'hC000] = LI_A0;          mem[16'hC001] = 8'h80;
    mem[16'hC002] = 8'b01_110_001;  mem[16'hC003] = 8'h00; // MOV ph, a0
    mem[16'hC004] = HLT;            mem[16'hC005] = 8'h00;
    run(20);
    check(uut.ph, 8'h80, "MOV ph, a0");

    // ===== JMP (ptr) =====
    reset_cpu;
    mem[16'hC000] = LI_PH;          mem[16'hC001] = 8'hC0;
    mem[16'hC002] = LI_PL;          mem[16'hC003] = 8'h20;
    mem[16'hC004] = 8'b10_111_001;  mem[16'hC005] = 8'h00; // JMP (ptr) → $C020
    mem[16'hC006] = LI_A0;          mem[16'hC007] = 8'hFF; // skipped
    mem[16'hC008] = HLT;            mem[16'hC009] = 8'h00;
    mem[16'hC020] = LI_A0;          mem[16'hC021] = 8'h99;
    mem[16'hC022] = HLT;            mem[16'hC023] = 8'h00;
    run(30);
    check(uut.a0, 8'h99, "JMP (ptr)");

    // ===== SHL =====
    reset_cpu;
    mem[16'hC000] = LI_A0;          mem[16'hC001] = 8'h25; // 0010_0101
    mem[16'hC002] = 8'b00_110_010;  mem[16'hC003] = 8'h00; // SHL (op=6, bit1=1)
    mem[16'hC004] = HLT;            mem[16'hC005] = 8'h00;
    run(20);
    check(uut.a0, 8'h4A, "SHL ($25<<1=$4A)");

    // ===== SHR =====
    reset_cpu;
    mem[16'hC000] = LI_A0;          mem[16'hC001] = 8'h4A; // 0100_1010
    mem[16'hC002] = 8'b00_111_010;  mem[16'hC003] = 8'h00; // SHR (op=7, bit1=1)
    mem[16'hC004] = HLT;            mem[16'hC005] = 8'h00;
    run(20);
    check(uut.a0, 8'h25, "SHR ($4A>>1=$25)");

    // ===== RESULTS =====
    $display("");
    $display("========================================");
    $display("  RV8-G Testbench Results");
    $display("  PASS: %0d / %0d", pass_count, test_num);
    if (fail_count > 0)
        $display("  FAIL: %0d", fail_count);
    else
        $display("  ALL TESTS PASSED!");
    $display("========================================");
    $finish;
end

endmodule
