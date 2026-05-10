// ============================================================
// RV8 CPU Testbench v2
// ============================================================
`timescale 1ns / 1ps

module rv8_tb;
    reg clk, rst_n, nmi_n, irq_n;
    wire [15:0] addr_bus;
    wire [7:0] data_bus;
    wire mem_rd_n, mem_wr_n, halt;

    // Memory (64KB)
    reg [7:0] mem [0:65535];

    // Bidirectional data bus
    wire [7:0] mem_data_out = mem[addr_bus];
    assign data_bus = (!mem_rd_n) ? mem_data_out : 8'bz;

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

    // Clock: 10ns period for fast simulation
    initial clk = 0;
    always #5 clk = ~clk;

    // Test infrastructure
    integer test_num, pass_count, fail_count;
    integer cycle_count;

    always @(posedge clk) cycle_count <= cycle_count + 1;

    task reset_cpu;
    begin
        rst_n = 0;
        cycle_count = 0;
        #20 rst_n = 1;
    end
    endtask

    task wait_halt;
        input integer max_cycles;
    begin
        while (!halt && cycle_count < max_cycles)
            @(posedge clk);
    end
    endtask

    task check;
        input [7:0] expected;
        input [7:0] actual;
        input [8*20:1] name;
    begin
        if (expected === actual) begin
            $display("  PASS: %0s = 0x%02h", name, actual);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: %0s = 0x%02h (expected 0x%02h)", name, actual, expected);
            fail_count = fail_count + 1;
        end
    end
    endtask

    // Access CPU internals for checking
    wire [7:0] cpu_a0 = CPU.a0;
    wire [7:0] cpu_t0 = CPU.t0;
    wire [7:0] cpu_sp = CPU.sp;
    wire [7:0] cpu_pl = CPU.pl;
    wire [7:0] cpu_ph = CPU.ph;
    wire [15:0] cpu_pc = CPU.pc;
    wire cpu_z = CPU.fz;
    wire cpu_c = CPU.fc;
    wire cpu_n = CPU.fn;

    initial begin
        $dumpfile("rv8_cpu.vcd");
        $dumpvars(0, rv8_tb);

        nmi_n = 1; irq_n = 1;
        pass_count = 0; fail_count = 0;

        // Clear memory to NOP (0xFE 0x00)
        begin : init_mem
            integer i;
            for (i = 0; i < 65536; i = i + 2) begin
                mem[i] = 8'hFE; mem[i+1] = 8'h00;
            end
        end

        // Reset vector → 0xC000
        mem[16'hFFFC] = 8'h00;
        mem[16'hFFFD] = 8'hC0;

        // =============================================
        // TEST 1: LI a0, 42
        // =============================================
        $display("\n=== TEST 1: LI a0, 42 ===");
        mem[16'hC000] = 8'h11; mem[16'hC001] = 8'h2A; // LI a0, 0x2A (42)
        mem[16'hC002] = 8'hFF; mem[16'hC003] = 8'h00; // HLT
        reset_cpu;
        wait_halt(50);
        check(8'h2A, cpu_a0, "a0");

        // =============================================
        // TEST 2: LI a0, 10; ADDI a0, 5
        // =============================================
        $display("\n=== TEST 2: ADDI ===");
        mem[16'hC000] = 8'h11; mem[16'hC001] = 8'h0A; // LI a0, 10
        mem[16'hC002] = 8'h16; mem[16'hC003] = 8'h05; // ADDI a0, 5
        mem[16'hC004] = 8'hFF; mem[16'hC005] = 8'h00; // HLT
        reset_cpu;
        wait_halt(50);
        check(8'h0F, cpu_a0, "a0"); // 10+5=15

        // =============================================
        // TEST 3: LI a0, 3; SUBI loop (count to 0)
        // =============================================
        $display("\n=== TEST 3: SUBI loop ===");
        mem[16'hC000] = 8'h11; mem[16'hC001] = 8'h03; // LI a0, 3
        mem[16'hC002] = 8'h17; mem[16'hC003] = 8'h01; // SUBI a0, 1
        mem[16'hC004] = 8'h31; mem[16'hC005] = 8'hFC; // BNE -4 (back to C002)
        mem[16'hC006] = 8'hFF; mem[16'hC007] = 8'h00; // HLT
        reset_cpu;
        wait_halt(100);
        check(8'h00, cpu_a0, "a0"); // should be 0 after loop
        check(1'b1, cpu_z, "Z flag");

        // =============================================
        // TEST 4: LI pl/ph, SB, LB via pointer
        // =============================================
        $display("\n=== TEST 4: Store/Load ptr ===");
        mem[16'hC000] = 8'h11; mem[16'hC001] = 8'hAB; // LI a0, 0xAB
        mem[16'hC002] = 8'h12; mem[16'hC003] = 8'h00; // LI pl, 0x00
        mem[16'hC004] = 8'h13; mem[16'hC005] = 8'h20; // LI ph, 0x20
        mem[16'hC006] = 8'h21; mem[16'hC007] = 8'h00; // SB a0, (ptr)
        mem[16'hC008] = 8'h11; mem[16'hC009] = 8'h00; // LI a0, 0 (clear)
        mem[16'hC00A] = 8'h20; mem[16'hC00B] = 8'h00; // LB a0, (ptr)
        mem[16'hC00C] = 8'hFF; mem[16'hC00D] = 8'h00; // HLT
        reset_cpu;
        wait_halt(100);
        check(8'hAB, cpu_a0, "a0"); // loaded back
        check(8'hAB, mem[16'h2000], "mem[0x2000]");

        // =============================================
        // TEST 5: Pointer auto-increment
        // =============================================
        $display("\n=== TEST 5: ptr+ ===");
        mem[16'h2000] = 8'h11; mem[16'h2001] = 8'h22; mem[16'h2002] = 8'h33;
        mem[16'hC000] = 8'h12; mem[16'hC001] = 8'h00; // LI pl, 0x00
        mem[16'hC002] = 8'h13; mem[16'hC003] = 8'h20; // LI ph, 0x20
        mem[16'hC004] = 8'h22; mem[16'hC005] = 8'h00; // LB a0, (ptr+)
        mem[16'hC006] = 8'h22; mem[16'hC007] = 8'h00; // LB a0, (ptr+)
        mem[16'hC008] = 8'h22; mem[16'hC009] = 8'h00; // LB a0, (ptr+)
        mem[16'hC00A] = 8'hFF; mem[16'hC00B] = 8'h00; // HLT
        reset_cpu;
        wait_halt(100);
        check(8'h33, cpu_a0, "a0"); // last byte read
        check(8'h03, cpu_pl, "pl"); // incremented 3 times

        // =============================================
        // TEST 6: Flags (CLC, SEC)
        // =============================================
        $display("\n=== TEST 6: CLC/SEC ===");
        mem[16'hC000] = 8'hF1; mem[16'hC001] = 8'h00; // SEC
        mem[16'hC002] = 8'hF0; mem[16'hC003] = 8'h00; // CLC
        mem[16'hC004] = 8'hFF; mem[16'hC005] = 8'h00; // HLT
        reset_cpu;
        wait_halt(50);
        check(1'b0, cpu_c, "C flag"); // CLC cleared it

        // =============================================
        // RESULTS
        // =============================================
        $display("\n========================================");
        $display("RESULTS: %0d passed, %0d failed", pass_count, fail_count);
        $display("========================================");
        if (fail_count == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");

        #100 $finish;
    end

    // Timeout
    initial begin
        #1000000;
        $display("TIMEOUT!");
        $finish;
    end
endmodule
