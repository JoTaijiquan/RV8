// Lab 4: Instruction Register — Simulation
// Run: iverilog -o lab4 lab4_ir_tb.v && vvp lab4
`timescale 1ns/1ns

module lab4_ir_tb;
    reg clk = 0, rst_n = 1;
    reg [15:0] pc;
    reg [7:0] ir_opcode, ir_operand;
    reg state; // 0=fetch opcode, 1=fetch operand

    // ROM: instruction pairs
    reg [7:0] rom [0:7];
    wire [7:0] data_bus = rom[pc[2:0]];

    // PC
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 0;
        else pc <= pc + 1;
    end

    // State toggle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= 0;
        else state <= ~state;
    end

    // IR latch
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin ir_opcode <= 0; ir_operand <= 0; end
        else if (state == 0) ir_opcode <= data_bus;
        else ir_operand <= data_bus;
    end

    always #50 clk = ~clk;

    initial begin
        rom[0]=8'h11; rom[1]=8'h05;  // LI a0, 5
        rom[2]=8'h16; rom[3]=8'h03;  // ADDI 3
        rom[4]=8'hFF; rom[5]=8'h00;  // HLT
        rom[6]=8'h00; rom[7]=8'h00;
    end

    initial begin
        $dumpfile("lab4.vcd"); $dumpvars(0, lab4_ir_tb);
        $display("=== Lab 4: Instruction Register ===");

        rst_n = 0; #100; rst_n = 1;

        @(posedge clk); #1; // fetch opcode
        @(posedge clk); #1; // fetch operand
        $display("Instr 1: opcode=%02X operand=%02X (expect 11 05)", ir_opcode, ir_operand);

        @(posedge clk); #1;
        @(posedge clk); #1;
        $display("Instr 2: opcode=%02X operand=%02X (expect 16 03)", ir_opcode, ir_operand);

        @(posedge clk); #1;
        @(posedge clk); #1;
        $display("Instr 3: opcode=%02X operand=%02X (expect FF 00)", ir_opcode, ir_operand);

        if (ir_opcode == 8'hFF && ir_operand == 8'h00) $display("Lab 4 PASSED");
        else $display("Lab 4 FAILED");
        $finish;
    end
endmodule
