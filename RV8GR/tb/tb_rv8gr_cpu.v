// RV8-GR CPU Testbench
// Tests all major instruction types in 3-cycle execution

`timescale 1ns / 1ps

module tb_rv8gr_cpu;

    reg        clk;
    reg        rst_n;
    wire [15:0] addr_bus;
    wire        rom_ce_n;
    wire        ram_ce_n;
    wire        ram_we_n;
    wire [7:0]  data_bus;
    wire        halted;

    rv8gr_cpu uut (
        .clk(clk),
        .rst_n(rst_n),
        .addr_bus(addr_bus),
        .rom_ce_n(rom_ce_n),
        .ram_ce_n(ram_ce_n),
        .ram_we_n(ram_we_n),
        .data_bus(data_bus),
        .halted(halted)
    );

    // Clock: 100 MHz (10ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    integer errors;
    integer test_num;

    task run_instruction;
    begin
        // 3 clock cycles: fetch_ctrl, fetch_oper, execute
        @(posedge clk); // fetch control
        @(posedge clk); // fetch operand
        @(posedge clk); // execute
        #1; // settle
    end
    endtask

    task check_ac;
        input [7:0] expected;
        input [8*32-1:0] msg;
    begin
        if (uut.ac !== expected) begin
            $display("FAIL test %0d: %0s — AC=%02h, expected %02h",
                     test_num, msg, uut.ac, expected);
            errors = errors + 1;
        end else begin
            $display("PASS test %0d: %0s — AC=%02h", test_num, msg, uut.ac);
        end
    end
    endtask

    task check_ram;
        input [7:0] addr;
        input [7:0] expected;
        input [8*32-1:0] msg;
    begin
        if (uut.ram[addr] !== expected) begin
            $display("FAIL test %0d: %0s — RAM[%02h]=%02h, expected %02h",
                     test_num, msg, addr, uut.ram[addr], expected);
            errors = errors + 1;
        end else begin
            $display("PASS test %0d: %0s — RAM[%02h]=%02h",
                     test_num, msg, addr, uut.ram[addr]);
        end
    end
    endtask

    task check_pc;
        input [15:0] expected;
        input [8*32-1:0] msg;
    begin
        if (uut.pc !== expected) begin
            $display("FAIL test %0d: %0s — PC=%04h, expected %04h",
                     test_num, msg, uut.pc, expected);
            errors = errors + 1;
        end else begin
            $display("PASS test %0d: %0s — PC=%04h", test_num, msg, uut.pc);
        end
    end
    endtask

    // Control byte encodings:
    // LI   a0, imm:    MUX_SEL=1, AC_WR=1              = 8'h30
    // ADDI a0, imm:    AC_WR=1                          = 8'h10
    // SUBI a0, imm:    ALU_SUB=1, AC_WR=1              = 8'h90
    // ADD  a0, rs:     SOURCE_TYPE=1, AC_WR=1          = 8'h18
    // XOR  a0, rs:     XOR_MODE=1, SOURCE_TYPE=1, AC_WR=1 = 8'h58
    // MV   rd, a0:     STORE=1                          = 8'h04
    // MV   a0, rs:     SOURCE_TYPE=1, MUX_SEL=1, AC_WR=1 = 8'h38
    // BEQ  addr:       BRANCH=1                         = 8'h02
    // BNE  addr:       BRANCH=1, ALU_SUB=1             = 8'h82
    // JMP  addr:       JUMP=1                           = 8'h01

    initial begin
        errors = 0;
        test_num = 0;

        // Pre-load RAM registers for tests
        uut.ram[2] = 8'hAA; // r2 = $AA
        uut.ram[3] = 8'h07; // r3 = $07

        // Load ROM program at $8000 (offset 0 in rom array)
        // Test 1: LI a0, $42
        uut.rom[0]  = 8'h30; uut.rom[1]  = 8'h42;
        // Test 2: ADDI a0, $10
        uut.rom[2]  = 8'h10; uut.rom[3]  = 8'h10;
        // Test 3: SUBI a0, $05
        uut.rom[4]  = 8'h90; uut.rom[5]  = 8'h05;
        // Test 4: ADD a0, r3 (RAM[$03]=$07)
        uut.rom[6]  = 8'h18; uut.rom[7]  = 8'h03;
        // Test 5: XOR a0, r2 (RAM[$02]=$AA)
        uut.rom[8]  = 8'h58; uut.rom[9]  = 8'h02;
        // Test 6: MV r1, a0 (STORE to RAM[$01])
        uut.rom[10] = 8'h04; uut.rom[11] = 8'h01;
        // Test 7: MV a0, r1 (load from RAM[$01])
        uut.rom[12] = 8'h38; uut.rom[13] = 8'h01;
        // Test 8: LI a0, $00 (set Z=1 for BEQ test)
        uut.rom[14] = 8'h30; uut.rom[15] = 8'h00;
        // Test 8 cont: BEQ to $20 (should be taken, Z=1)
        uut.rom[16] = 8'h02; uut.rom[17] = 8'h20;
        // At ROM offset $20: LI a0, $FF (landing pad for BEQ)
        uut.rom[32] = 8'h30; uut.rom[33] = 8'hFF;
        // Test 9: BNE to $30 (should NOT be taken, Z=0 after LI $FF)
        // Wait — after LI $FF, Z=0. BNE branches when Z=0.
        // We want "not taken" so we need Z=1. Let's LI $00 first.
        uut.rom[34] = 8'h30; uut.rom[35] = 8'h00; // LI $00, Z=1
        // BNE to $30 — Z=1, BNE needs Z=0 to branch, so NOT taken
        uut.rom[36] = 8'h82; uut.rom[37] = 8'h30;
        // Test 10: Loop — LI $03, then SUBI+BNE loop
        uut.rom[38] = 8'h30; uut.rom[39] = 8'h03; // LI a0, $03
        // Loop body at offset 40: SUBI a0, $01
        uut.rom[40] = 8'h90; uut.rom[41] = 8'h01;
        // BNE back to offset 40 (ROM addr $8028)
        uut.rom[42] = 8'h82; uut.rom[43] = 8'h28;
        // After loop: ECALL (halt)
        uut.rom[44] = 8'h00; uut.rom[45] = 8'h00;

        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;
        #1;

        // Test 1: LI a0, $42
        test_num = 1;
        run_instruction;
        check_ac(8'h42, "LI a0, $42");

        // Test 2: ADDI a0, $10 → $42+$10=$52
        test_num = 2;
        run_instruction;
        check_ac(8'h52, "ADDI a0, $10");

        // Test 3: SUBI a0, $05 → $52-$05=$4D
        test_num = 3;
        run_instruction;
        check_ac(8'h4D, "SUBI a0, $05");

        // Test 4: ADD a0, r3 → $4D+$07=$54
        test_num = 4;
        run_instruction;
        check_ac(8'h54, "ADD a0, r3");

        // Test 5: XOR a0, r2 → $54 XOR $AA = $FE
        test_num = 5;
        run_instruction;
        check_ac(8'hFE, "XOR a0, r2");

        // Test 6: MV r1, a0 → RAM[$01]=$FE
        test_num = 6;
        run_instruction;
        check_ram(8'h01, 8'hFE, "MV r1, a0");

        // Test 7: MV a0, r1 → AC=RAM[$01]=$FE
        test_num = 7;
        run_instruction;
        check_ac(8'hFE, "MV a0, r1");

        // Setup for test 8: LI a0, $00 (sets Z=1)
        run_instruction;

        // Test 8: BEQ taken (Z=1, branch to $8020)
        test_num = 8;
        run_instruction;
        check_pc(16'h8020, "BEQ taken");

        // Landing: LI a0, $FF (at $8020)
        run_instruction;

        // Setup for test 9: LI a0, $00 (Z=1)
        run_instruction;

        // Test 9: BNE not taken (Z=1, BNE needs Z=0)
        test_num = 9;
        run_instruction;
        // PC should advance past BNE (not branch to $8030)
        check_pc(16'h8026, "BNE not taken");

        // Test 10: Loop — LI $03, then SUBI+BNE ×3
        test_num = 10;
        run_instruction; // LI a0, $03
        // Loop 3 times: SUBI $01, BNE back
        run_instruction; // SUBI → $02
        run_instruction; // BNE taken (Z=0) → back to $8028
        run_instruction; // SUBI → $01
        run_instruction; // BNE taken (Z=0) → back to $8028
        run_instruction; // SUBI → $00
        run_instruction; // BNE not taken (Z=1) → fall through
        check_ac(8'h00, "Loop SUBI+BNE");
        check_pc(16'h802C, "Loop exit PC");

        // Summary
        $display("");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);

        $finish;
    end

    // Timeout
    initial begin
        #10000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
