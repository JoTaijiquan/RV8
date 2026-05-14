`timescale 1ns / 1ps
module tb_rv802_cpu;

reg clk, rst_n, nmi_n, irq_n;
wire [15:0] addr; wire [7:0] data_out; reg [7:0] data_in;
wire mem_rd, mem_wr;

reg [7:0] mem [0:65535];
always @(*) data_in = mem[addr];
always @(posedge clk) if (mem_wr) mem[addr] <= data_out;

rv802_cpu uut (.clk(clk),.rst_n(rst_n),.nmi_n(nmi_n),.irq_n(irq_n),
    .addr(addr),.data_out(data_out),.data_in(data_in),.mem_rd(mem_rd),.mem_wr(mem_wr));

initial clk=0; always #5 clk=~clk;
integer pass_count=0, fail_count=0, test_num=0;

task run(input integer n); integer i; begin for(i=0;i<n;i=i+1) @(posedge clk); end endtask
task check(input [7:0] got, input [7:0] exp, input [255:0] name); begin
    test_num=test_num+1;
    if(got===exp) pass_count=pass_count+1;
    else begin fail_count=fail_count+1; $display("FAIL #%0d: %0s got=$%02X exp=$%02X",test_num,name,got,exp); end
end endtask
task reset_cpu; integer i; begin for(i=0;i<65536;i=i+1) mem[i]=0; rst_n=0; #20; rst_n=1; end endtask

// Opcode builders
// Class 01 (immediate): {01, op[2:0], rd[2:0]}
`define LI(rd)    {2'b01, 3'd0, rd}
`define ADDI(rd)  {2'b01, 3'd1, rd}
`define SUBI(rd)  {2'b01, 3'd2, rd}
`define ANDI(rd)  {2'b01, 3'd3, rd}
`define ORI(rd)   {2'b01, 3'd4, rd}
`define XORI(rd)  {2'b01, 3'd5, rd}
`define CMPI(rd)  {2'b01, 3'd6, rd}
// Class 00 (reg-reg): {00, op[2:0], rd[2:0]}, operand={rs[2:0], 5'b0}
`define ADD(rd)   {2'b00, 3'd0, rd}
`define SUB(rd)   {2'b00, 3'd1, rd}
`define AND_R(rd) {2'b00, 3'd2, rd}
`define OR_R(rd)  {2'b00, 3'd3, rd}
`define XOR_R(rd) {2'b00, 3'd4, rd}
`define SLT(rd)   {2'b00, 3'd5, rd}
`define SHL(rd)   {2'b00, 3'd6, rd}
`define SHR(rd)   {2'b00, 3'd7, rd}
`define RS(r)     {r, 5'b00000}
// Class 10 (memory): {10, op[2:0], rd[2:0]}
`define LB(rd)    {2'b10, 3'd0, rd}
`define SB(rd)    {2'b10, 3'd1, rd}
`define LB_ZP(rd) {2'b10, 3'd2, rd}
`define SB_ZP(rd) {2'b10, 3'd3, rd}
`define PUSH(rd)  {2'b10, 3'd4, rd}
`define POP(rd)   {2'b10, 3'd5, rd}
// Class 11 (control): {11, op[2:0], cond/rd[2:0]}
`define BEQ       {2'b11, 3'd0, 3'd0}
`define BNE       {2'b11, 3'd1, 3'd0}
`define BRA       {2'b11, 3'd4, 3'd0}
`define JAL(rd)   {2'b11, 3'd5, rd}
`define JMP       {2'b11, 3'd6, 3'd0}
`define SYS       {2'b11, 3'd7, 3'd0}
localparam HLT = 8'h01;
localparam NOP = 8'h00;

initial begin
    $dumpfile("rv802.vcd"); $dumpvars(0, tb_rv802_cpu);
    nmi_n=1; irq_n=1;

    // 1. LI r1, $42
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h42;
    mem[16'hC002]=`SYS; mem[16'hC003]=HLT;
    run(16); check(uut.r[1], 8'h42, "LI r1,$42");

    // 2. ADDI r1, $10
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h20;
    mem[16'hC002]=`ADDI(3'd1); mem[16'hC003]=8'h10;
    mem[16'hC004]=`SYS; mem[16'hC005]=HLT;
    run(20); check(uut.r[1], 8'h30, "ADDI r1,$10");

    // 3. SUBI r1, $08
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h20;
    mem[16'hC002]=`SUBI(3'd1); mem[16'hC003]=8'h08;
    mem[16'hC004]=`SYS; mem[16'hC005]=HLT;
    run(20); check(uut.r[1], 8'h18, "SUBI r1,$08");

    // 4. ANDI
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'hF5;
    mem[16'hC002]=`ANDI(3'd1); mem[16'hC003]=8'h0F;
    mem[16'hC004]=`SYS; mem[16'hC005]=HLT;
    run(20); check(uut.r[1], 8'h05, "ANDI");

    // 5. ORI
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'hA0;
    mem[16'hC002]=`ORI(3'd1); mem[16'hC003]=8'h05;
    mem[16'hC004]=`SYS; mem[16'hC005]=HLT;
    run(20); check(uut.r[1], 8'hA5, "ORI");

    // 6. XORI
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'hFF;
    mem[16'hC002]=`XORI(3'd1); mem[16'hC003]=8'h0F;
    mem[16'hC004]=`SYS; mem[16'hC005]=HLT;
    run(20); check(uut.r[1], 8'hF0, "XORI");

    // 7. ADD r1, r2 (register-register)
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h10;
    mem[16'hC002]=`LI(3'd2); mem[16'hC003]=8'h20;
    mem[16'hC004]=`ADD(3'd1); mem[16'hC005]=`RS(3'd2);
    mem[16'hC006]=`SYS; mem[16'hC007]=HLT;
    run(28); check(uut.r[1], 8'h30, "ADD r1,r2");

    // 8. SUB r1, r2
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h30;
    mem[16'hC002]=`LI(3'd2); mem[16'hC003]=8'h10;
    mem[16'hC004]=`SUB(3'd1); mem[16'hC005]=`RS(3'd2);
    mem[16'hC006]=`SYS; mem[16'hC007]=HLT;
    run(28); check(uut.r[1], 8'h20, "SUB r1,r2");

    // 9. SHL r1
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h25;
    mem[16'hC002]=`SHL(3'd1); mem[16'hC003]=8'h00;
    mem[16'hC004]=`SYS; mem[16'hC005]=HLT;
    run(24); check(uut.r[1], 8'h4A, "SHL");

    // 10. SHR r1
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h4A;
    mem[16'hC002]=`SHR(3'd1); mem[16'hC003]=8'h00;
    mem[16'hC004]=`SYS; mem[16'hC005]=HLT;
    run(24); check(uut.r[1], 8'h25, "SHR");

    // 11. SB/LB zero-page
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h99;
    mem[16'hC002]=`SB_ZP(3'd1); mem[16'hC003]=8'h42;
    mem[16'hC004]=`LI(3'd1); mem[16'hC005]=8'h00;
    mem[16'hC006]=`LB_ZP(3'd1); mem[16'hC007]=8'h42;
    mem[16'hC008]=`SYS; mem[16'hC009]=HLT;
    run(40); check(uut.r[1], 8'h99, "SB/LB zp");

    // 12. PUSH/POP
    reset_cpu;
    mem[16'hC000]=`LI(3'd7); mem[16'hC001]=8'hFF; // sp=FF
    mem[16'hC002]=`LI(3'd1); mem[16'hC003]=8'h55;
    mem[16'hC004]=`PUSH(3'd1); mem[16'hC005]=8'h00;
    mem[16'hC006]=`LI(3'd1); mem[16'hC007]=8'h00;
    mem[16'hC008]=`POP(3'd1); mem[16'hC009]=8'h00;
    mem[16'hC00A]=`SYS; mem[16'hC00B]=HLT;
    run(48); check(uut.r[1], 8'h55, "PUSH/POP");

    // 13. BEQ taken
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h00; // Z=1 (LI 0)
    mem[16'hC002]=`CMPI(3'd1); mem[16'hC003]=8'h00; // ensure Z=1
    mem[16'hC004]=`BEQ; mem[16'hC005]=8'h02; // skip 2
    mem[16'hC006]=`LI(3'd1); mem[16'hC007]=8'hFF; // skipped
    mem[16'hC008]=`LI(3'd1); mem[16'hC009]=8'h42; // land
    mem[16'hC00A]=`SYS; mem[16'hC00B]=HLT;
    run(32); check(uut.r[1], 8'h42, "BEQ taken");

    // 14. BNE taken
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h05;
    mem[16'hC002]=`CMPI(3'd1); mem[16'hC003]=8'h03; // 5-3≠0, Z=0
    mem[16'hC004]=`BNE; mem[16'hC005]=8'h02;
    mem[16'hC006]=`LI(3'd1); mem[16'hC007]=8'hFF; // skipped
    mem[16'hC008]=`LI(3'd1); mem[16'hC009]=8'h33;
    mem[16'hC00A]=`SYS; mem[16'hC00B]=HLT;
    run(32); check(uut.r[1], 8'h33, "BNE taken");

    // 15. Loop (ADDI + CMPI + BNE)
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h00;
    mem[16'hC002]=`ADDI(3'd1); mem[16'hC003]=8'h01; // r1++
    mem[16'hC004]=`CMPI(3'd1); mem[16'hC005]=8'h05; // r1==5?
    mem[16'hC006]=`BNE; mem[16'hC007]=8'hFA; // -6 → back to ADDI
    mem[16'hC008]=`SYS; mem[16'hC009]=HLT;
    run(100); check(uut.r[1], 8'h05, "Loop");

    // 16. JMP
    reset_cpu;
    mem[16'hC000]=`LI(3'd6); mem[16'hC001]=8'hC0; // r6=page
    mem[16'hC002]=`JMP; mem[16'hC003]=8'h20; // jump to $C020
    mem[16'hC004]=`SYS; mem[16'hC005]=HLT;
    mem[16'hC020]=`LI(3'd1); mem[16'hC021]=8'h77;
    mem[16'hC022]=`SYS; mem[16'hC023]=HLT;
    run(24); check(uut.r[1], 8'h77, "JMP");

    // 17. BRA (unconditional)
    reset_cpu;
    mem[16'hC000]=`BRA; mem[16'hC001]=8'h04; // skip to $C006
    mem[16'hC002]=`LI(3'd1); mem[16'hC003]=8'hFF; // skipped
    mem[16'hC004]=`LI(3'd1); mem[16'hC005]=8'hEE; // skipped
    mem[16'hC006]=`LI(3'd1); mem[16'hC007]=8'h11;
    mem[16'hC008]=`SYS; mem[16'hC009]=HLT;
    run(30); check(uut.r[1], 8'h11, "BRA");

    // 18. Multiple registers
    reset_cpu;
    mem[16'hC000]=`LI(3'd1); mem[16'hC001]=8'h11;
    mem[16'hC002]=`LI(3'd2); mem[16'hC003]=8'h22;
    mem[16'hC004]=`LI(3'd3); mem[16'hC005]=8'h33;
    mem[16'hC006]=`SYS; mem[16'hC007]=HLT;
    run(30);
    check(uut.r[1], 8'h11, "r1=$11");
    check(uut.r[2], 8'h22, "r2=$22");
    check(uut.r[3], 8'h33, "r3=$33");

    // 19. r0 always zero
    reset_cpu;
    mem[16'hC000]=`LI(3'd0); mem[16'hC001]=8'hFF; // try to write r0
    mem[16'hC002]=`SYS; mem[16'hC003]=HLT;
    run(16); check(uut.r[0], 8'h00, "r0=0 always");

    // ===== RESULTS =====
    $display("");
    $display("========================================");
    $display("  RV802 Testbench Results");
    $display("  PASS: %0d / %0d", pass_count, test_num);
    if (fail_count > 0) $display("  FAIL: %0d", fail_count);
    else $display("  ALL TESTS PASSED!");
    $display("========================================");
    $finish;
end
endmodule
