// ============================================================
// RV8 CPU Testbench
// ============================================================
`timescale 1ns / 1ps

module rv8_tb;
    reg clk, rst_n, nmi_n, irq_n;
    wire [15:0] addr_bus;
    wire [7:0] data_bus;
    wire mem_rd_n, mem_wr_n, halt;

    // Memory (64KB)
    reg [7:0] mem [0:65535];
    wire [7:0] mem_out = mem[addr_bus];
    reg [7:0] data_drive;
    wire data_oe = ~mem_wr_n;

    assign data_bus = (~mem_rd_n) ? mem_out : 8'bz;
    assign data_bus = data_oe ? 8'bz : 8'bz; // CPU drives on write

    // CPU instance
    rv8_cpu CPU (
        .clk(clk), .rst_n(rst_n),
        .nmi_n(nmi_n), .irq_n(irq_n),
        .addr_bus(addr_bus), .data_bus(data_bus),
        .mem_rd_n(mem_rd_n), .mem_wr_n(mem_wr_n),
        .halt(halt)
    );

    // Memory write
    always @(posedge clk) begin
        if (!mem_wr_n)
            mem[addr_bus] <= data_bus;
    end

    // Clock: 3.5 MHz = ~143ns period
    initial clk = 0;
    always #143 clk = ~clk;

    // Test program loader
    task load_program;
        input [15:0] start_addr;
        input [15:0] length;
        integer i;
        begin
            // Program loaded externally via initial block
        end
    endtask

    // Monitor
    integer cycle_count;
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;
        if (cycle_count < 200)
            $display("T=%0d addr=%04h data=%02h rd=%b wr=%b halt=%b",
                     cycle_count, addr_bus, data_bus, ~mem_rd_n, ~mem_wr_n, halt);
    end

    // Test sequence
    initial begin
        $dumpfile("rv8_cpu.vcd");
        $dumpvars(0, rv8_tb);

        // Initialize
        clk = 0; rst_n = 0; nmi_n = 1; irq_n = 1;
        cycle_count = 0;

        // Clear memory
        begin : clear_mem
            integer i;
            for (i = 0; i < 65536; i = i + 1) mem[i] = 8'hFF; // HLT
        end

        // =============================================
        // TEST 1: LI a0, 42 + HLT
        // =============================================
        $display("\n=== TEST 1: LI a0, 42 ===");
        mem[16'hC000] = 8'h11; mem[16'hC001] = 8'h2A; // LI a0, 42
        mem[16'hC002] = 8'hFF; mem[16'hC003] = 8'h00; // HLT
        // Reset vector points to 0xC000
        mem[16'hFFFC] = 8'h00; mem[16'hFFFD] = 8'hC0;

        // Reset
        #500 rst_n = 1;
        wait(halt || cycle_count > 50);
        $display("TEST 1: halt=%b cycles=%0d", halt, cycle_count);

        // =============================================
        // TEST 2: ADD — a0 = 10 + 20
        // =============================================
        $display("\n=== TEST 2: ADD ===");
        rst_n = 0; cycle_count = 0;
        mem[16'hC000] = 8'h11; mem[16'hC001] = 8'h0A; // LI a0, 10
        mem[16'hC002] = 8'h14; mem[16'hC003] = 8'h05; // LI t0, 5 (opcode 0x14 = LI t0)
        mem[16'hC004] = 8'h00; mem[16'hC005] = 8'h05; // ADD t0 (reg 5)
        mem[16'hC006] = 8'hFF; mem[16'hC007] = 8'h00; // HLT
        #500 rst_n = 1;
        wait(halt || cycle_count > 50);
        $display("TEST 2: halt=%b cycles=%0d", halt, cycle_count);

        // =============================================
        // TEST 3: Branch (BNE loop)
        // =============================================
        $display("\n=== TEST 3: BNE loop ===");
        rst_n = 0; cycle_count = 0;
        mem[16'hC000] = 8'h11; mem[16'hC001] = 8'h03; // LI a0, 3
        // loop:
        mem[16'hC002] = 8'h16; mem[16'hC003] = 8'h01; // SUBI a0, 1 (was ADDI mapped)
        mem[16'hC004] = 8'h31; mem[16'hC005] = 8'hFC; // BNE -4 (back to C002)
        mem[16'hC006] = 8'hFF; mem[16'hC007] = 8'h00; // HLT
        #500 rst_n = 1;
        wait(halt || cycle_count > 100);
        $display("TEST 3: halt=%b cycles=%0d (expect ~20 for 3 iterations)", halt, cycle_count);

        // =============================================
        // TEST 4: Memory store/load via pointer
        // =============================================
        $display("\n=== TEST 4: Store/Load via ptr ===");
        rst_n = 0; cycle_count = 0;
        mem[16'hC000] = 8'h11; mem[16'hC001] = 8'h55; // LI a0, 0x55
        mem[16'hC002] = 8'h12; mem[16'hC003] = 8'h00; // LI pl, 0x00
        mem[16'hC004] = 8'h13; mem[16'hC005] = 8'h20; // LI ph, 0x20
        mem[16'hC006] = 8'h21; mem[16'hC007] = 8'h02; // SB a0, (ptr)
        mem[16'hC008] = 8'h11; mem[16'hC009] = 8'h00; // LI a0, 0 (clear a0)
        mem[16'hC00A] = 8'h20; mem[16'hC00B] = 8'h02; // LB a0, (ptr)
        mem[16'hC00C] = 8'hFF; mem[16'hC00D] = 8'h00; // HLT
        #500 rst_n = 1;
        wait(halt || cycle_count > 80);
        $display("TEST 4: halt=%b cycles=%0d mem[0x2000]=%02h", halt, cycle_count, mem[16'h2000]);

        // =============================================
        // TEST 5: Conditional skip (SKIPNZ)
        // =============================================
        $display("\n=== TEST 5: SKIPNZ ===");
        rst_n = 0; cycle_count = 0;
        mem[16'hC000] = 8'h11; mem[16'hC001] = 8'h01; // LI a0, 1 (non-zero)
        mem[16'hC002] = 8'h18; mem[16'hC003] = 8'h01; // CMPI a0, 1 → Z=1
        mem[16'hC004] = 8'h38; mem[16'hC005] = 8'h00; // SKIPNZ (skip if Z==0; Z==1 so DON'T skip)
        mem[16'hC006] = 8'h11; mem[16'hC007] = 8'hAA; // LI a0, 0xAA (should execute)
        mem[16'hC008] = 8'hFF; mem[16'hC009] = 8'h00; // HLT
        #500 rst_n = 1;
        wait(halt || cycle_count > 50);
        $display("TEST 5: halt=%b cycles=%0d", halt, cycle_count);

        // =============================================
        // TEST 6: Pointer auto-increment (ptr+)
        // =============================================
        $display("\n=== TEST 6: ptr+ auto-increment ===");
        rst_n = 0; cycle_count = 0;
        // Store 3 bytes at 0x2000-0x2002
        mem[16'h2000] = 8'h11; mem[16'h2001] = 8'h22; mem[16'h2002] = 8'h33;
        mem[16'hC000] = 8'h12; mem[16'hC001] = 8'h00; // LI pl, 0x00
        mem[16'hC002] = 8'h13; mem[16'hC003] = 8'h20; // LI ph, 0x20
        mem[16'hC004] = 8'h22; mem[16'hC005] = 8'h02; // LB a0, (ptr+)
        mem[16'hC006] = 8'h22; mem[16'hC007] = 8'h02; // LB a0, (ptr+)
        mem[16'hC008] = 8'h22; mem[16'hC009] = 8'h02; // LB a0, (ptr+)
        mem[16'hC00A] = 8'hFF; mem[16'hC00B] = 8'h00; // HLT
        #500 rst_n = 1;
        wait(halt || cycle_count > 80);
        $display("TEST 6: halt=%b cycles=%0d (ptr should be 0x2003)", halt, cycle_count);

        // Done
        #1000;
        $display("\n=== ALL TESTS COMPLETE ===");
        $finish;
    end

    // Timeout
    initial begin
        #500000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
