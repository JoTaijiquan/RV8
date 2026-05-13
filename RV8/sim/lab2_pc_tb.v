// Lab 2: Program Counter — Simulation
// Run: iverilog -o lab2 lab2_pc_tb.v && vvp lab2
`timescale 1ns/1ns

module lab2_pc_tb;
    reg clk = 0, rst_n = 1;
    reg pc_inc = 1;  // always counting
    reg [15:0] pc;

    // 74HC161 x4 model (16-bit counter)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 16'd0;
        else if (pc_inc) pc <= pc + 1;
    end

    always #50 clk = ~clk;

    initial begin
        $dumpfile("lab2.vcd"); $dumpvars(0, lab2_pc_tb);
        $display("=== Lab 2: Program Counter ===");

        // Reset
        rst_n = 0; #100; rst_n = 1;
        $display("After reset: PC = %04X (expect 0000)", pc);

        // Count 16 steps
        repeat(16) @(posedge clk);
        #1;
        $display("After 16 clocks: PC = %04X (expect 0010)", pc);

        // Count to 256
        repeat(240) @(posedge clk);
        #1;
        $display("After 256 clocks: PC = %04X (expect 0100)", pc);

        // Reset mid-count
        rst_n = 0; #100; rst_n = 1;
        @(posedge clk); #1;
        $display("After mid-reset: PC = %04X (expect 0001)", pc);

        if (pc == 16'h0001) $display("Lab 2 PASSED");
        else $display("Lab 2 FAILED");
        $finish;
    end
endmodule
