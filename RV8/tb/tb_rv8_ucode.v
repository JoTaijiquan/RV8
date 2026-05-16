`timescale 1ns / 1ps
module tb_rv8_ucode;

reg clk, rst_n, irq_n;
wire [15:0] addr;
wire [7:0] data_out;
reg [7:0] data_in;
wire mem_rd, mem_wr;

reg [7:0] mem [0:65535];
always @(*) data_in = mem[addr];
always @(posedge clk) if (mem_wr) mem[addr] <= data_out;

rv8_cpu uut (.clk(clk), .rst_n(rst_n), .irq_n(irq_n),
    .addr(addr), .data_out(data_out), .data_in(data_in),
    .mem_rd(mem_rd), .mem_wr(mem_wr));

initial clk = 0;
always #5 clk = ~clk;

integer pass_count = 0, fail_count = 0, test_num = 0;

task run(input integer n); integer i; begin
    for (i = 0; i < n; i = i + 1) @(posedge clk);
end endtask

task check(input [7:0] got, input [7:0] exp, input [255:0] name); begin
    test_num = test_num + 1;
    if (got === exp) pass_count = pass_count + 1;
    else begin fail_count = fail_count + 1;
        $display("FAIL #%0d: %0s got=$%02X exp=$%02X", test_num, name, got, exp);
    end
end endtask

task reset_cpu; integer i; begin
    for (i = 0; i < 65536; i = i + 1) mem[i] = 8'hF8; // NOP (11_111_000)
    rst_n = 0; #20; rst_n = 1;
end endtask

// Opcodes
localparam LI_R1  = 8'b01_000_001; // LI r1, imm
localparam LI_R2  = 8'b01_000_010; // LI r2, imm
localparam ADDI_R1= 8'b01_001_001; // ADDI r1, imm
localparam SUBI_R1= 8'b01_010_001; // SUBI r1, imm
localparam ADD_R1 = 8'b00_000_001; // ADD r1, r1, rs (rs from operand[7:5])
localparam SUB_R1 = 8'b00_001_001; // SUB r1, r1, rs
localparam BEQ    = 8'b11_000_000; // BEQ
localparam BNE    = 8'b11_001_000; // BNE
localparam HLT    = 8'b11_111_000; // SYS (HLT when operand=$01)

initial begin
    $dumpfile("rv8_ucode.vcd");
    $dumpvars(0, tb_rv8_ucode);
    irq_n = 1;

    // === TEST 1: LI r1, $42 ===
    reset_cpu;
    mem[16'hC000] = LI_R1;  mem[16'hC001] = 8'h42;
    mem[16'hC002] = HLT;    mem[16'hC003] = 8'h01;
    run(30);
    check(uut.regs[1], 8'h42, "LI r1, $42");

    // === TEST 2: ADDI r1, $10 ===
    reset_cpu;
    mem[16'hC000] = LI_R1;   mem[16'hC001] = 8'h20;
    mem[16'hC002] = ADDI_R1; mem[16'hC003] = 8'h10;
    mem[16'hC004] = HLT;     mem[16'hC005] = 8'h01;
    run(40);
    check(uut.regs[1], 8'h30, "ADDI r1, $10");

    // === TEST 3: SUBI r1, $05 ===
    reset_cpu;
    mem[16'hC000] = LI_R1;   mem[16'hC001] = 8'h20;
    mem[16'hC002] = SUBI_R1; mem[16'hC003] = 8'h05;
    mem[16'hC004] = HLT;     mem[16'hC005] = 8'h01;
    run(40);
    check(uut.regs[1], 8'h1B, "SUBI r1, $05");

    // === TEST 4: ADD r1, r1, r2 ===
    reset_cpu;
    mem[16'hC000] = LI_R1;   mem[16'hC001] = 8'h10;
    mem[16'hC002] = LI_R2;   mem[16'hC003] = 8'h20;
    mem[16'hC004] = ADD_R1;  mem[16'hC005] = 8'b010_00000; // rs=r2
    mem[16'hC006] = HLT;     mem[16'hC007] = 8'h01;
    run(50);
    check(uut.regs[1], 8'h30, "ADD r1, r1, r2");

    // === TEST 5: r0 always zero ===
    reset_cpu;
    mem[16'hC000] = 8'b01_000_000; // LI r0, $FF
    mem[16'hC001] = 8'hFF;
    mem[16'hC002] = HLT; mem[16'hC003] = 8'h01;
    run(30);
    check(uut.regs[0], 8'h00, "r0 always zero");

    // === RESULTS ===
    $display("");
    $display("========================================");
    $display("  RV8 Microcode-Driven Testbench");
    $display("  PASS: %0d / %0d", pass_count, test_num);
    if (fail_count > 0) $display("  FAIL: %0d", fail_count);
    else $display("  ALL TESTS PASSED!");
    $display("========================================");
    $finish;
end

endmodule
