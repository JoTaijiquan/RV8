// Lab 7: Pointer + Address Mux — Simulation
// Run: iverilog -o lab7 lab7_pointer_tb.v && vvp lab7
`timescale 1ns/1ns

module lab7_pointer_tb;
    reg clk = 0, rst_n = 1;
    reg [15:0] pc;
    reg [15:0] ptr;
    reg ptr_inc = 0, ptr_load = 0;
    reg [7:0] ptr_data;
    reg addr_sel = 0; // 0=PC, 1=pointer
    reg mem_wr = 0, mem_rd = 0;

    wire [15:0] addr_bus = addr_sel ? ptr : pc;

    // RAM model
    reg [7:0] ram [0:255];
    reg [7:0] data_out;
    wire [7:0] data_bus = mem_wr ? data_out : ram[addr_bus[7:0]];

    // PC
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 0;
        else if (!addr_sel) pc <= pc + 1;
    end

    // Pointer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) ptr <= 0;
        else if (ptr_load) ptr <= {8'h20, ptr_data};
        else if (ptr_inc) ptr <= ptr + 1;
    end

    // RAM write
    always @(posedge clk) begin
        if (mem_wr && addr_sel) ram[addr_bus[7:0]] <= data_out;
    end

    always #50 clk = ~clk;

    initial begin
        $dumpfile("lab7.vcd"); $dumpvars(0, lab7_pointer_tb);
        $display("=== Lab 7: Pointer + Address Mux ===");

        rst_n = 0; #100; rst_n = 1;

        // Test PC mode
        repeat(4) @(posedge clk);
        #1;
        $display("PC mode: addr = %04X (expect 0004)", addr_bus);

        // Load pointer to 8'h2000
        ptr_data = 8'h00; ptr_load = 1;
        @(posedge clk); #1;
        ptr_load = 0;
        $display("Pointer loaded: ptr = %04X (expect 2000)", ptr);

        // Switch to pointer mode, write 8'h42
        addr_sel = 1; data_out = 8'h42; mem_wr = 1;
        @(posedge clk); #1;
        mem_wr = 0;
        $display("Wrote 8'h42 to addr %04X", addr_bus);

        // Increment pointer
        ptr_inc = 1; @(posedge clk); #1; ptr_inc = 0;
        $display("After inc: ptr = %04X (expect 2001)", ptr);

        // Write 8'h55 to 8'h2001
        data_out = 8'h55; mem_wr = 1;
        @(posedge clk); #1;
        mem_wr = 0;

        // Read back 8'h2000
        ptr_inc = 0;
        ptr_data = 8'h00; ptr_load = 1;
        @(posedge clk); #1;
        ptr_load = 0;
        mem_rd = 1; #1;
        $display("Read back [8'h2000] = %02X (expect 42)", ram[8'h00]);
        $display("Read back [8'h2001] = %02X (expect 55)", ram[8'h01]);

        if (ram[0] == 8'h42 && ram[1] == 8'h55) $display("Lab 7 PASSED");
        else $display("Lab 7 FAILED");
        $finish;
    end
endmodule
