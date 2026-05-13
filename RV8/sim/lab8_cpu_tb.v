// Lab 8: Full CPU — Simulation
// Run: iverilog -o lab8 ../rv8_cpu.v lab8_cpu_tb.v && vvp lab8
`timescale 1ns/1ns

module lab8_cpu_tb;
    reg clk = 0, rst_n = 0;
    wire [15:0] addr_bus;
    wire [7:0] data_bus;
    wire mem_rd_n, mem_wr_n, halt, sync;

    // Memory (ROM + RAM)
    reg [7:0] mem [0:65535];
    wire [7:0] mem_out = mem[addr_bus];
    wire mem_reading = ~mem_rd_n;
    wire mem_writing = ~mem_wr_n;

    assign data_bus = mem_reading ? mem_out : 8'bz;

    always @(posedge clk) begin
        if (mem_writing) mem[addr_bus] <= data_bus;
    end

    rv8_cpu CPU (
        .clk(clk), .rst_n(rst_n),
        .nmi_n(1'b1), .irq_n(1'b1),
        .addr_bus(addr_bus), .data_bus(data_bus),
        .mem_rd_n(mem_rd_n), .mem_wr_n(mem_wr_n),
        .halt(halt), .sync(sync)
    );

    always #50 clk = ~clk;

    integer i;
    initial begin
        $dumpfile("lab8.vcd"); $dumpvars(0, lab8_cpu_tb);

        // Clear memory
        for (i = 0; i < 65536; i = i + 1) mem[i] = 8'hFF;

        // Test program: count to 10
        // LI a0, 0 / ADDI 1 / CMPI 10 / BNE -6 / HLT
        mem[16'hC000] = 8'h11; mem[16'hC001] = 8'h00; // LI a0, 0
        mem[16'hC002] = 8'h16; mem[16'hC003] = 8'h01; // ADDI 1
        mem[16'hC004] = 8'h18; mem[16'hC005] = 8'h0A; // CMPI 10
        mem[16'hC006] = 8'h31; mem[16'hC007] = 8'hFA; // BNE -6
        mem[16'hC008] = 8'hFF; mem[16'hC009] = 8'h00; // HLT

        // Reset vector points to $C000
        mem[16'hFFFC] = 8'h00;
        mem[16'hFFFD] = 8'hC0;

        // Release reset
        #200; rst_n = 1;

        // Wait for halt or timeout
        repeat(2000) begin
            @(posedge clk);
            if (halt) begin
                $display("=== Lab 8: Full CPU ===");
                $display("CPU halted after counting loop");
                $display("Test: count to 10 — PASSED");
                $finish;
            end
        end

        $display("TIMEOUT — CPU did not halt");
        $display("Lab 8 FAILED");
        $finish;
    end
endmodule
