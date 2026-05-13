// Lab 3: ROM Fetch — Simulation
// Run: iverilog -o lab3 lab3_rom_tb.v && vvp lab3
`timescale 1ns/1ns

module lab3_rom_tb;
    reg clk = 0, rst_n = 1;
    reg [15:0] pc;
    wire [7:0] data_bus;

    // ROM model (preloaded with test pattern)
    reg [7:0] rom [0:15];
    assign data_bus = rom[pc[3:0]];

    // PC (counter)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 0;
        else pc <= pc + 1;
    end

    always #50 clk = ~clk;

    initial begin
        // Load test pattern
        rom[0]=8'hAA; rom[1]=8'h55; rom[2]=8'h01; rom[3]=8'h02;
        rom[4]=8'h04; rom[5]=8'h08; rom[6]=8'h10; rom[7]=8'h20;
        rom[8]=8'h40; rom[9]=8'h80; rom[10]=8'hFF; rom[11]=8'h00;
        rom[12]=8'hDE; rom[13]=8'hAD; rom[14]=8'hBE; rom[15]=8'hEF;
    end

    initial begin
        $dumpfile("lab3.vcd"); $dumpvars(0, lab3_rom_tb);
        $display("=== Lab 3: ROM Fetch ===");

        rst_n = 0; #100; rst_n = 1;

        @(posedge clk); #1;
        $display("Fetch 0: data = %02X (expect AA)", data_bus);
        @(posedge clk); #1;
        $display("Fetch 1: data = %02X (expect 55)", data_bus);
        @(posedge clk); #1;
        $display("Fetch 2: data = %02X (expect 01)", data_bus);

        repeat(7) @(posedge clk);
        #1;
        $display("Fetch 10: data = %02X (expect FF)", data_bus);
        @(posedge clk); #1;
        $display("Fetch 11: data = %02X (expect 00)", data_bus);

        if (data_bus == 8'h00) $display("Lab 3 PASSED");
        else $display("Lab 3 FAILED");
        $finish;
    end
endmodule
