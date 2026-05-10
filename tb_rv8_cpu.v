// RV8 Comprehensive Testbench
`timescale 1ns / 1ps
module rv8_tb;
    reg clk, rst_n, nmi_n, irq_n;
    wire [15:0] addr_bus;
    wire [7:0] data_bus;
    wire mem_rd_n, mem_wr_n, halt;
    reg [7:0] mem [0:65535];
    assign data_bus = (!mem_rd_n) ? mem[addr_bus] : 8'bz;
    rv8_cpu CPU(.clk(clk),.rst_n(rst_n),.nmi_n(nmi_n),.irq_n(irq_n),
        .addr_bus(addr_bus),.data_bus(data_bus),.mem_rd_n(mem_rd_n),.mem_wr_n(mem_wr_n),.halt(halt));
    always @(posedge clk) if(!mem_wr_n) mem[addr_bus]<=data_bus;
    initial clk=0; always #5 clk=~clk;
    integer pass_count=0, fail_count=0, cycle_count;
    always @(posedge clk) cycle_count<=cycle_count+1;
    task reset; begin rst_n=0; #30; rst_n=1; cycle_count=0; end endtask
    task whalt; input integer mx; begin @(posedge clk); while(!halt&&cycle_count<mx) @(posedge clk); end endtask
    task chk8; input[7:0] exp,act; input[8*16:1] nm;
        begin if(exp===act) begin pass_count=pass_count+1; end
        else begin $display("  FAIL: %0s=%02h exp=%02h",nm,act,exp); fail_count=fail_count+1; end end endtask
    task chk1; input exp,act; input[8*16:1] nm;
        begin if(exp===act) begin pass_count=pass_count+1; end
        else begin $display("  FAIL: %0s=%0b exp=%0b",nm,act,exp); fail_count=fail_count+1; end end endtask
    wire[7:0] A=CPU.a0, T=CPU.t0, S=CPU.sp, PL=CPU.pl, PH=CPU.ph, PG=CPU.pg;
    wire FZ=CPU.fz, FC=CPU.fc, FN=CPU.fn;

    task init_mem; begin : im integer i;
        for(i=0;i<65536;i=i+2) begin mem[i]=8'hFE; mem[i+1]=8'h00; end
        mem[16'hFFFC]=8'h00; mem[16'hFFFD]=8'hC0; end endtask

    initial begin
        $dumpfile("rv8_cpu.vcd"); $dumpvars(0,rv8_tb);
        nmi_n=1; irq_n=1;
        // === ALU REG TESTS ===
        $display("--- ALU Register ---");
        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h0A; // LI a0,10
        mem[16'hC002]=8'h14; mem[16'hC003]=8'h03; // LI t0,3
        mem[16'hC004]=8'h00; mem[16'hC005]=8'h05; // ADD t0
        mem[16'hC006]=8'hFF; mem[16'hC007]=8'h00;
        reset; whalt(60); chk8(8'd13,A,"ADD");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h0A;
        mem[16'hC002]=8'h14; mem[16'hC003]=8'h03;
        mem[16'hC004]=8'h01; mem[16'hC005]=8'h05; // SUB t0
        mem[16'hC006]=8'hFF; mem[16'hC007]=8'h00;
        reset; whalt(60); chk8(8'd7,A,"SUB");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'hF0;
        mem[16'hC002]=8'h14; mem[16'hC003]=8'h0F;
        mem[16'hC004]=8'h02; mem[16'hC005]=8'h05; // AND t0
        mem[16'hC006]=8'hFF; mem[16'hC007]=8'h00;
        reset; whalt(60); chk8(8'h00,A,"AND");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'hF0;
        mem[16'hC002]=8'h14; mem[16'hC003]=8'h0F;
        mem[16'hC004]=8'h03; mem[16'hC005]=8'h05; // OR t0
        mem[16'hC006]=8'hFF; mem[16'hC007]=8'h00;
        reset; whalt(60); chk8(8'hFF,A,"OR");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'hAA;
        mem[16'hC002]=8'h14; mem[16'hC003]=8'hFF;
        mem[16'hC004]=8'h04; mem[16'hC005]=8'h05; // XOR t0
        mem[16'hC006]=8'hFF; mem[16'hC007]=8'h00;
        reset; whalt(60); chk8(8'h55,A,"XOR");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h05;
        mem[16'hC002]=8'h14; mem[16'hC003]=8'h05;
        mem[16'hC004]=8'h05; mem[16'hC005]=8'h05; // CMP t0 (equal)
        mem[16'hC006]=8'hFF; mem[16'hC007]=8'h00;
        reset; whalt(60); chk8(8'h05,A,"CMP no-write"); chk1(1,FZ,"CMP Z");

        // === IMMEDIATE TESTS ===
        $display("--- Immediate ---");
        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h10; // LI a0,16
        mem[16'hC002]=8'h16; mem[16'hC003]=8'h04; // ADDI 4
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'h14,A,"ADDI");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h10;
        mem[16'hC002]=8'h17; mem[16'hC003]=8'h01; // SUBI 1
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'h0F,A,"SUBI");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'hAB;
        mem[16'hC002]=8'h19; mem[16'hC003]=8'h0F; // ANDI 0x0F
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'h0B,A,"ANDI");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'hA0;
        mem[16'hC002]=8'h1A; mem[16'hC003]=8'h05; // ORI 0x05
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'hA5,A,"ORI");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'hFF;
        mem[16'hC002]=8'h1B; mem[16'hC003]=8'hAA; // XORI 0xAA
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'h55,A,"XORI");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'hAB;
        mem[16'hC002]=8'h1C; mem[16'hC003]=8'h0F; // TST 0x0F
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'hAB,A,"TST no-write"); chk1(0,FZ,"TST Z");

        // === SHIFT/UNARY ===
        $display("--- Shift/Unary ---");
        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h81; // LI a0, 0x81
        mem[16'hC002]=8'h40; mem[16'hC003]=8'h00; // SHL
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'h02,A,"SHL"); chk1(1,FC,"SHL C");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h81;
        mem[16'hC002]=8'h41; mem[16'hC003]=8'h00; // SHR
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'h40,A,"SHR"); chk1(1,FC,"SHR C");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h05;
        mem[16'hC002]=8'h44; mem[16'hC003]=8'h00; // INC
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'h06,A,"INC");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h05;
        mem[16'hC002]=8'h45; mem[16'hC003]=8'h00; // DEC
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'h04,A,"DEC");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'hAA;
        mem[16'hC002]=8'h46; mem[16'hC003]=8'h00; // NOT
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'h55,A,"NOT");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'hA5;
        mem[16'hC002]=8'h47; mem[16'hC003]=8'h00; // SWAP
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(60); chk8(8'h5A,A,"SWAP");

        // === POINTER OPS ===
        $display("--- Pointer ---");
        init_mem; mem[16'hC000]=8'h12; mem[16'hC001]=8'hFF; // LI pl,0xFF
        mem[16'hC002]=8'h13; mem[16'hC003]=8'h10; // LI ph,0x10
        mem[16'hC004]=8'h48; mem[16'hC005]=8'h00; // INC16
        mem[16'hC006]=8'hFF; mem[16'hC007]=8'h00;
        reset; whalt(60); chk8(8'h00,PL,"INC16 pl"); chk8(8'h11,PH,"INC16 ph");

        // === BRANCH ===
        $display("--- Branch ---");
        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h03; // LI a0,3
        mem[16'hC002]=8'h17; mem[16'hC003]=8'h01; // SUBI 1
        mem[16'hC004]=8'h31; mem[16'hC005]=8'hFC; // BNE -4
        mem[16'hC006]=8'hFF; mem[16'hC007]=8'h00;
        reset; whalt(100); chk8(8'h00,A,"BNE loop"); chk1(1,FZ,"BNE Z");

        // === STORE/LOAD ===
        $display("--- Store/Load ---");
        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h77; // LI a0,0x77
        mem[16'hC002]=8'h15; mem[16'hC003]=8'h50; // LI pg,0x50
        mem[16'hC004]=8'h2B; mem[16'hC005]=8'h10; // SB a0,[pg:0x10]
        mem[16'hC006]=8'h11; mem[16'hC007]=8'h00; // LI a0,0
        mem[16'hC008]=8'h2A; mem[16'hC009]=8'h10; // LB a0,[pg:0x10]
        mem[16'hC00A]=8'hFF; mem[16'hC00B]=8'h00;
        reset; whalt(100); chk8(8'h77,A,"pg:imm"); chk8(8'h77,mem[16'h5010],"mem[5010]");

        // === SYSTEM ===
        $display("--- System ---");
        init_mem; mem[16'hC000]=8'hF1; mem[16'hC001]=8'h00; // SEC
        mem[16'hC002]=8'hFF; mem[16'hC003]=8'h00;
        reset; whalt(80); chk1(1,FC,"SEC");

        init_mem; mem[16'hC000]=8'hF1; mem[16'hC001]=8'h00; // SEC
        mem[16'hC002]=8'hF0; mem[16'hC003]=8'h00; // CLC
        mem[16'hC004]=8'hFF; mem[16'hC005]=8'h00;
        reset; whalt(80); chk1(0,FC,"CLC");

        // === SKIP ===
        $display("--- Skip ---");
        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h00; // LI a0,0 (Z=? not set yet)
        mem[16'hC002]=8'h18; mem[16'hC003]=8'h00; // CMPI 0 → Z=1
        mem[16'hC004]=8'h37; mem[16'hC005]=8'h00; // SKIPZ (Z=1 → skip next)
        mem[16'hC006]=8'h11; mem[16'hC007]=8'hBB; // LI a0,0xBB (should be skipped)
        mem[16'hC008]=8'hFF; mem[16'hC009]=8'h00;
        reset; whalt(80); chk8(8'h00,A,"SKIPZ skipped");

        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h05; // LI a0,5
        mem[16'hC002]=8'h18; mem[16'hC003]=8'h05; // CMPI 5 → Z=1
        mem[16'hC004]=8'h38; mem[16'hC005]=8'h00; // SKIPNZ (Z=1 → don't skip)
        mem[16'hC006]=8'h11; mem[16'hC007]=8'hCC; // LI a0,0xCC (should execute)
        mem[16'hC008]=8'hFF; mem[16'hC009]=8'h00;
        reset; whalt(80); chk8(8'hCC,A,"SKIPNZ not-skip");

        // === PUSH/POP ===
        $display("--- Push/Pop ---");
        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'h42; // LI a0,0x42
        mem[16'hC002]=8'h2C; mem[16'hC003]=8'h02; // PUSH a0
        mem[16'hC004]=8'h11; mem[16'hC005]=8'h00; // LI a0,0
        mem[16'hC006]=8'h2D; mem[16'hC007]=8'h02; // POP a0
        mem[16'hC008]=8'hFF; mem[16'hC009]=8'h00;
        reset; whalt(80); chk8(8'h42,A,"PUSH/POP");

        // === JMP ===
        $display("--- JMP ---");
        init_mem; mem[16'hC000]=8'h12; mem[16'hC001]=8'h10; // LI pl,0x10
        mem[16'hC002]=8'h13; mem[16'hC003]=8'hC0; // LI ph,0xC0
        mem[16'hC004]=8'h3C; mem[16'hC005]=8'h00; // JMP (ptr) → 0xC010
        mem[16'hC006]=8'h11; mem[16'hC007]=8'hEE; // should be skipped
        mem[16'hC010]=8'h11; mem[16'hC011]=8'h99; // LI a0,0x99
        mem[16'hC012]=8'hFF; mem[16'hC013]=8'h00;
        reset; whalt(80); chk8(8'h99,A,"JMP");

        // === JAL/RET ===
        $display("--- JAL/RET ---");
        init_mem; mem[16'hC000]=8'h12; mem[16'hC001]=8'h20; // LI pl,0x20
        mem[16'hC002]=8'h13; mem[16'hC003]=8'hC0; // LI ph,0xC0
        mem[16'hC004]=8'h3D; mem[16'hC005]=8'h00; // JAL (ptr) → 0xC020
        mem[16'hC006]=8'hFF; mem[16'hC007]=8'h00; // HLT (return here)
        // Subroutine at 0xC020:
        mem[16'hC020]=8'h11; mem[16'hC021]=8'h77; // LI a0,0x77
        mem[16'hC022]=8'h3E; mem[16'hC023]=8'h00; // RET
        reset; whalt(120); chk8(8'h77,A,"JAL/RET");

        // === ZERO PAGE ===
        $display("--- Zero Page ---");
        init_mem; mem[16'hC000]=8'h11; mem[16'hC001]=8'hDE; // LI a0,0xDE
        mem[16'hC002]=8'h29; mem[16'hC003]=8'h42; // SB a0,[zp+0x42]
        mem[16'hC004]=8'h11; mem[16'hC005]=8'h00; // LI a0,0
        mem[16'hC006]=8'h28; mem[16'hC007]=8'h42; // LB a0,[zp+0x42]
        mem[16'hC008]=8'hFF; mem[16'hC009]=8'h00;
        reset; whalt(80); chk8(8'hDE,A,"zero-page");

        // === ROL/ROR ===
        $display("--- ROL/ROR ---");
        init_mem; mem[16'hC000]=8'hF1; mem[16'hC001]=8'h00; // SEC (C=1)
        mem[16'hC002]=8'h11; mem[16'hC003]=8'h00; // LI a0,0x00
        mem[16'hC004]=8'h42; mem[16'hC005]=8'h00; // ROL (shift in C=1)
        mem[16'hC006]=8'hFF; mem[16'hC007]=8'h00;
        reset; whalt(80); chk8(8'h01,A,"ROL");

        // === RESULTS ===
        $display("\n============================");
        $display("PASS: %0d  FAIL: %0d", pass_count, fail_count);
        $display("============================");
        if(fail_count==0) $display("ALL TESTS PASSED!");
        #100; $finish;
    end
    initial begin #2000000; $display("TIMEOUT"); $finish; end
endmodule
