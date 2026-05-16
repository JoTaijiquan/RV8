`timescale 1ns / 1ps
module tb_rv8g_cpu;

reg clk, rst_n, nmi_n, irq_n;
wire [15:0] addr;
wire [7:0]  data_out;
reg  [7:0]  data_in;
wire        mem_rd, mem_wr;

reg [7:0] mem [0:65535];
always @(*) data_in = mem[addr];
always @(posedge clk) if (mem_wr) mem[addr] <= data_out;

rv8g_cpu uut (.clk(clk), .rst_n(rst_n), .nmi_n(nmi_n), .irq_n(irq_n),
    .addr(addr), .data_out(data_out), .data_in(data_in),
    .mem_rd(mem_rd), .mem_wr(mem_wr));

initial clk = 0;
always #5 clk = ~clk;

integer pass_count = 0, fail_count = 0, test_num = 0;

task run(input integer cycles); integer i; begin
    for (i = 0; i < cycles; i = i + 1) @(posedge clk);
end endtask

task check(input [7:0] got, input [7:0] exp, input [255:0] name); begin
    test_num = test_num + 1;
    if (got === exp) pass_count = pass_count + 1;
    else begin fail_count = fail_count + 1;
        $display("FAIL #%0d: %0s — got $%02X, expected $%02X", test_num, name, got, exp);
    end
end endtask

task check16(input [15:0] got, input [15:0] exp, input [255:0] name); begin
    test_num = test_num + 1;
    if (got === exp) pass_count = pass_count + 1;
    else begin fail_count = fail_count + 1;
        $display("FAIL #%0d: %0s — got $%04X, expected $%04X", test_num, name, got, exp);
    end
end endtask

task reset_cpu; integer i; begin
    for (i = 0; i < 65536; i = i + 1) mem[i] = 8'h00;
    rst_n = 0; #20; rst_n = 1;
end endtask

// === OPCODE DEFINITIONS ===
// Class 00: ALU — {00, op[2:0], mod[1:0]}
//   mod[0]=immediate, mod[1]=carry/shift
localparam ADD_T  = 8'b00_000_000;
localparam ADDI   = 8'b00_000_001;
localparam ADC_T  = 8'b00_000_010;
localparam ADCI   = 8'b00_000_011;
localparam SUB_T  = 8'b00_001_000;
localparam SUBI   = 8'b00_001_001;
localparam SBC_T  = 8'b00_001_010;
localparam SBCI   = 8'b00_001_011;
localparam AND_T  = 8'b00_010_000;
localparam ANDI   = 8'b00_010_001;
localparam OR_T   = 8'b00_011_000;
localparam ORI    = 8'b00_011_001;
localparam XOR_T  = 8'b00_100_000;
localparam XORI   = 8'b00_100_001;
localparam CMP_T  = 8'b00_101_000;
localparam CMPI   = 8'b00_101_001;
localparam INC_A  = 8'b00_110_000;
localparam SHL    = 8'b00_110_010;
localparam DEC_A  = 8'b00_111_000;
localparam MOV_TA = 8'b00_111_001; // MOV t0←a0
localparam SHR    = 8'b00_111_010;

// Class 01: LDST — {01, op[2:0], mod[2:0]}
localparam LI_A0  = 8'b01_000_000;
localparam LI_T0  = 8'b01_000_001;
localparam LI_SP  = 8'b01_000_010;
localparam LI_PL  = 8'b01_000_011;
localparam LI_PH  = 8'b01_000_100;
localparam LB_PTR = 8'b01_001_000;
localparam SB_PTR = 8'b01_010_000;
localparam LB_ZP  = 8'b01_011_000;
localparam SB_ZP  = 8'b01_100_000;
localparam LB_INC = 8'b01_101_000;
localparam MOV_PL = 8'b01_110_000; // MOV pl←a0
localparam MOV_PH = 8'b01_110_001; // MOV ph←a0

// Class 10: Branch — {10, op[2:0], mod[2:0]}
// New encoding: [4:3]=flag(00=Z,01=C,1x=always), [5]=invert
localparam BEQ    = 8'b10_000_000; // Z=1
localparam BCS    = 8'b10_001_000; // C=1
localparam BRA    = 8'b10_010_000; // always (bit4=1)
localparam BNE    = 8'b10_100_000; // Z=0 (inverted)
localparam BCC    = 8'b10_101_000; // C=0 (inverted)
localparam JMP    = 8'b10_111_000; // JMP imm
localparam JMP_P  = 8'b10_111_001; // JMP (ptr)

// Class 11: System — {11, op[2:0], mod[2:0]}
localparam PUSH_A = 8'b11_000_000;
localparam POP_A  = 8'b11_001_000;
localparam CALL   = 8'b11_010_000;
localparam RET    = 8'b11_011_000;
localparam NOP    = 8'b11_100_000;
localparam HLT    = 8'b11_101_000;
localparam EI     = 8'b11_110_000;
localparam DI     = 8'b11_111_000;

initial begin
    $dumpfile("rv8g.vcd"); $dumpvars(0, tb_rv8g_cpu);
    nmi_n = 1; irq_n = 1;

    // ========== CLASS 00: ALU ==========

    // 1. LI a0 + ADDI
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h10;
    mem[16'hC002]=ADDI;  mem[16'hC003]=8'h05;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.a0, 8'h15, "ADDI");

    // 2. SUBI
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h20;
    mem[16'hC002]=SUBI;  mem[16'hC003]=8'h08;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.a0, 8'h18, "SUBI");

    // 3. ANDI
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'hF5;
    mem[16'hC002]=ANDI;  mem[16'hC003]=8'h0F;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.a0, 8'h05, "ANDI");

    // 4. ORI
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'hA0;
    mem[16'hC002]=ORI;   mem[16'hC003]=8'h05;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.a0, 8'hA5, "ORI");

    // 5. XORI
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'hFF;
    mem[16'hC002]=XORI;  mem[16'hC003]=8'h0F;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.a0, 8'hF0, "XORI");

    // 6. ADD t0
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h10;
    mem[16'hC002]=LI_T0; mem[16'hC003]=8'h20;
    mem[16'hC004]=ADD_T; mem[16'hC005]=0;
    mem[16'hC006]=HLT;   mem[16'hC007]=0;
    run(24); check(uut.a0, 8'h30, "ADD t0");

    // 7. SUB t0
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h30;
    mem[16'hC002]=LI_T0; mem[16'hC003]=8'h10;
    mem[16'hC004]=SUB_T; mem[16'hC005]=0;
    mem[16'hC006]=HLT;   mem[16'hC007]=0;
    run(24); check(uut.a0, 8'h20, "SUB t0");

    // 8. INC
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h0F;
    mem[16'hC002]=INC_A; mem[16'hC003]=0;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.a0, 8'h10, "INC");

    // 9. DEC
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h10;
    mem[16'hC002]=DEC_A; mem[16'hC003]=0;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.a0, 8'h0F, "DEC");

    // 10. SHL
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h25;
    mem[16'hC002]=SHL;   mem[16'hC003]=0;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.a0, 8'h4A, "SHL");

    // 11. SHR
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h4A;
    mem[16'hC002]=SHR;   mem[16'hC003]=0;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.a0, 8'h25, "SHR");

    // 12. ADC (carry propagation)
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'hFF;
    mem[16'hC002]=ADDI;  mem[16'hC003]=8'h01; // a0=0, C=1
    mem[16'hC004]=LI_A0; mem[16'hC005]=8'h05;
    mem[16'hC006]=ADCI;  mem[16'hC007]=8'h00; // 5+0+C=6
    mem[16'hC008]=HLT;   mem[16'hC009]=0;
    run(32); check(uut.a0, 8'h06, "ADC");

    // 13. SBC (borrow propagation)
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h00;
    mem[16'hC002]=SUBI;  mem[16'hC003]=8'h01; // a0=FF, C=1(borrow)
    mem[16'hC004]=LI_A0; mem[16'hC005]=8'h10;
    mem[16'hC006]=SBCI;  mem[16'hC007]=8'h00; // 10-0-1=0F
    mem[16'hC008]=HLT;   mem[16'hC009]=0;
    run(32); check(uut.a0, 8'h0F, "SBC");

    // 14. MOV t0, a0
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h55;
    mem[16'hC002]=MOV_TA;mem[16'hC003]=0;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.t0, 8'h55, "MOV t0,a0");

    // 15. CMP (flags only, no store)
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h05;
    mem[16'hC002]=CMPI;  mem[16'hC003]=8'h05; // 5-5=0, Z=1
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.a0, 8'h05, "CMP no store");

    // ========== CLASS 01: LOAD/STORE ==========

    // 16. LI t0
    reset_cpu;
    mem[16'hC000]=LI_T0; mem[16'hC001]=8'hAB;
    mem[16'hC002]=HLT;   mem[16'hC003]=0;
    run(16); check(uut.t0, 8'hAB, "LI t0");

    // 17. LI sp
    reset_cpu;
    mem[16'hC000]=LI_SP; mem[16'hC001]=8'hFF;
    mem[16'hC002]=HLT;   mem[16'hC003]=0;
    run(16); check(uut.sp, 8'hFF, "LI sp");

    // 18. SB/LB zero-page
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h99;
    mem[16'hC002]=SB_ZP; mem[16'hC003]=8'h42;
    mem[16'hC004]=LI_A0; mem[16'hC005]=8'h00;
    mem[16'hC006]=LB_ZP; mem[16'hC007]=8'h42;
    mem[16'hC008]=HLT;   mem[16'hC009]=0;
    run(40); check(uut.a0, 8'h99, "SB/LB zp");

    // 19. SB/LB pointer
    reset_cpu;
    mem[16'hC000]=LI_PH; mem[16'hC001]=8'h00;
    mem[16'hC002]=LI_PL; mem[16'hC003]=8'h80;
    mem[16'hC004]=LI_A0; mem[16'hC005]=8'hBB;
    mem[16'hC006]=SB_PTR;mem[16'hC007]=0;
    mem[16'hC008]=LI_A0; mem[16'hC009]=8'h00;
    mem[16'hC00A]=LB_PTR;mem[16'hC00B]=0;
    mem[16'hC00C]=HLT;   mem[16'hC00D]=0;
    run(50); check(uut.a0, 8'hBB, "SB/LB ptr");

    // 20. LB (ptr+) auto-increment
    reset_cpu;
    mem[16'h0080]=8'hAA; mem[16'h0081]=8'h55; // data at $0080,$0081
    mem[16'hC000]=LI_PH; mem[16'hC001]=8'h00;
    mem[16'hC002]=LI_PL; mem[16'hC003]=8'h80;
    mem[16'hC004]=LB_INC;mem[16'hC005]=0; // read $0080, ptr→$0081
    mem[16'hC006]=LB_INC;mem[16'hC007]=0; // read $0081, ptr→$0082
    mem[16'hC008]=HLT;   mem[16'hC009]=0;
    run(40); check(uut.a0, 8'h55, "LB (ptr+)");

    // 21. MOV pl, a0
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h42;
    mem[16'hC002]=MOV_PL;mem[16'hC003]=0;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.pl, 8'h42, "MOV pl,a0");

    // 22. MOV ph, a0
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h80;
    mem[16'hC002]=MOV_PH;mem[16'hC003]=0;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.ph, 8'h80, "MOV ph,a0");

    // ========== CLASS 10: BRANCH ==========

    // 23. BEQ taken (Z=1)
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h00; // Z=1
    mem[16'hC002]=BEQ;   mem[16'hC003]=8'h02; // skip 2
    mem[16'hC004]=LI_A0; mem[16'hC005]=8'hFF; // skipped
    mem[16'hC006]=LI_A0; mem[16'hC007]=8'h42; // land here
    mem[16'hC008]=HLT;   mem[16'hC009]=0;
    run(28); check(uut.a0, 8'h42, "BEQ taken");

    // 24. BNE taken (Z=0)
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h01; // Z=0
    mem[16'hC002]=BNE;   mem[16'hC003]=8'h02; // skip 2
    mem[16'hC004]=LI_A0; mem[16'hC005]=8'hFF; // skipped
    mem[16'hC006]=LI_A0; mem[16'hC007]=8'h33; // land here
    mem[16'hC008]=HLT;   mem[16'hC009]=0;
    run(28); check(uut.a0, 8'h33, "BNE taken");

    // 25. BCS taken (C=1)
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'hFF;
    mem[16'hC002]=ADDI;  mem[16'hC003]=8'h01; // overflow → C=1
    mem[16'hC004]=BCS;   mem[16'hC005]=8'h02;
    mem[16'hC006]=LI_A0; mem[16'hC007]=8'hFF; // skipped
    mem[16'hC008]=LI_A0; mem[16'hC009]=8'h77;
    mem[16'hC00A]=HLT;   mem[16'hC00B]=0;
    run(32); check(uut.a0, 8'h77, "BCS taken");

    // 26. BCC taken (C=0)
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h01;
    mem[16'hC002]=ADDI;  mem[16'hC003]=8'h01; // no overflow → C=0
    mem[16'hC004]=BCC;   mem[16'hC005]=8'h02;
    mem[16'hC006]=LI_A0; mem[16'hC007]=8'hFF; // skipped
    mem[16'hC008]=LI_A0; mem[16'hC009]=8'h88;
    mem[16'hC00A]=HLT;   mem[16'hC00B]=0;
    run(32); check(uut.a0, 8'h88, "BCC taken");

    // 27. BRA (always)
    reset_cpu;
    mem[16'hC000]=BRA;   mem[16'hC001]=8'h02;
    mem[16'hC002]=LI_A0; mem[16'hC003]=8'hFF; // skipped
    mem[16'hC004]=LI_A0; mem[16'hC005]=8'h11;
    mem[16'hC006]=HLT;   mem[16'hC007]=0;
    run(20); check(uut.a0, 8'h11, "BRA");

    // 28. Loop (BNE backward)
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h00;
    mem[16'hC002]=INC_A; mem[16'hC003]=0;
    mem[16'hC004]=CMPI;  mem[16'hC005]=8'h03;
    mem[16'hC006]=BNE;   mem[16'hC007]=8'hFA; // -6
    mem[16'hC008]=HLT;   mem[16'hC009]=0;
    run(80); check(uut.a0, 8'h03, "Loop BNE");

    // 29. JMP absolute
    reset_cpu;
    mem[16'hC000]=LI_PH; mem[16'hC001]=8'hC0;
    mem[16'hC002]=JMP;   mem[16'hC003]=8'h20;
    mem[16'hC004]=HLT;   mem[16'hC005]=0; // skipped
    mem[16'hC020]=LI_A0; mem[16'hC021]=8'h66;
    mem[16'hC022]=HLT;   mem[16'hC023]=0;
    run(28); check(uut.a0, 8'h66, "JMP abs");

    // 30. JMP (ptr)
    reset_cpu;
    mem[16'hC000]=LI_PH; mem[16'hC001]=8'hC0;
    mem[16'hC002]=LI_PL; mem[16'hC003]=8'h30;
    mem[16'hC004]=JMP_P; mem[16'hC005]=0;
    mem[16'hC006]=HLT;   mem[16'hC007]=0; // skipped
    mem[16'hC030]=LI_A0; mem[16'hC031]=8'h99;
    mem[16'hC032]=HLT;   mem[16'hC033]=0;
    run(28); check(uut.a0, 8'h99, "JMP (ptr)");

    // ========== CLASS 11: SYSTEM ==========

    // 31. PUSH/POP
    reset_cpu;
    mem[16'hC000]=LI_SP; mem[16'hC001]=8'hFF;
    mem[16'hC002]=LI_A0; mem[16'hC003]=8'h55;
    mem[16'hC004]=PUSH_A;mem[16'hC005]=0;
    mem[16'hC006]=LI_A0; mem[16'hC007]=8'h00;
    mem[16'hC008]=POP_A; mem[16'hC009]=0;
    mem[16'hC00A]=HLT;   mem[16'hC00B]=0;
    run(44); check(uut.a0, 8'h55, "PUSH/POP");

    // 32. CALL/RET
    reset_cpu;
    mem[16'hC000]=LI_SP; mem[16'hC001]=8'hFF;
    mem[16'hC002]=LI_PH; mem[16'hC003]=8'hC0;
    mem[16'hC004]=CALL;  mem[16'hC005]=8'h20;
    mem[16'hC006]=HLT;   mem[16'hC007]=0;
    mem[16'hC020]=LI_A0; mem[16'hC021]=8'h77;
    mem[16'hC022]=RET;   mem[16'hC023]=0;
    run(50); check(uut.a0, 8'h77, "CALL/RET");

    // 33. NOP (doesn't crash)
    reset_cpu;
    mem[16'hC000]=LI_A0; mem[16'hC001]=8'h42;
    mem[16'hC002]=NOP;   mem[16'hC003]=0;
    mem[16'hC004]=HLT;   mem[16'hC005]=0;
    run(20); check(uut.a0, 8'h42, "NOP");

    // 34. EI/DI
    reset_cpu;
    mem[16'hC000]=EI;    mem[16'hC001]=0;
    mem[16'hC002]=HLT;   mem[16'hC003]=0;
    run(16); check(uut.flag_ie, 1'b1, "EI");

    // ========== RESULTS ==========
    $display("");
    $display("========================================");
    $display("  RV8-G Testbench — ALL 30 Instructions");
    $display("  PASS: %0d / %0d", pass_count, test_num);
    if (fail_count > 0)
        $display("  FAIL: %0d", fail_count);
    else
        $display("  ALL TESTS PASSED!");
    $display("========================================");
    $finish;
end

endmodule
