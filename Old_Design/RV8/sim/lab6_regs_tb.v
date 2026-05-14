// Lab 6: Registers — Simulation
// Run: iverilog -o lab6 lab6_regs_tb.v && vvp lab6
`timescale 1ns/1ns

module lab6_regs_tb;
    reg clk = 0, rst_n = 1;
    reg a0_clk = 0;
    reg [7:0] operand = 8'h00;
    reg sub = 0;

    // a0 register
    reg [7:0] a0;
    // ALU
    wire [7:0] b_xor = operand ^ {8{sub}};
    wire [8:0] sum = a0 + b_xor + sub;
    wire [7:0] result = sum[7:0];

    // a0 latch
    always @(posedge a0_clk or negedge rst_n) begin
        if (!rst_n) a0 <= 0;
        else a0 <= result;
    end

    always #50 clk = ~clk;

    initial begin
        $dumpfile("lab6.vcd"); $dumpvars(0, lab6_regs_tb);
        $display("=== Lab 6: Registers ===");

        // Reset
        rst_n = 0; #100; rst_n = 1; #10;
        $display("After reset: a0 = %02X (expect 00)", a0);

        // Load 5: a0 = 0 + 5
        sub = 0; operand = 8'h05; #10;
        a0_clk = 1; #10; a0_clk = 0; #10;
        $display("After +5: a0 = %02X (expect 05)", a0);

        // Add 3: a0 = 5 + 3
        operand = 8'h03; #10;
        a0_clk = 1; #10; a0_clk = 0; #10;
        $display("After +3: a0 = %02X (expect 08)", a0);

        // Add 3 again: a0 = 8 + 3
        #10; a0_clk = 1; #10; a0_clk = 0; #10;
        $display("After +3: a0 = %02X (expect 0B)", a0);

        // Subtract 1: a0 = 11 - 1
        sub = 1; operand = 8'h01; #10;
        a0_clk = 1; #10; a0_clk = 0; #10;
        $display("After -1: a0 = %02X (expect 0A)", a0);

        // Overflow: add 8'hF6 to get wrap
        sub = 0; operand = 8'hF6; #10;
        a0_clk = 1; #10; a0_clk = 0; #10;
        $display("After +F6: a0 = %02X (expect 00, wrap)", a0);

        if (a0 == 8'h00) $display("Lab 6 PASSED");
        else $display("Lab 6 FAILED");
        $finish;
    end
endmodule
