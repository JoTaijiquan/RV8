`timescale 1ns / 1ps
module tb_rv8gr_asm;

reg clk, rst_n;
wire [15:0] addr_bus;
wire rom_ce_n, ram_ce_n, ram_we_n, halted;
wire [7:0] data_bus;

rv8gr_cpu uut (.clk(clk), .rst_n(rst_n),
    .addr_bus(addr_bus), .rom_ce_n(rom_ce_n), .ram_ce_n(ram_ce_n),
    .ram_we_n(ram_we_n), .data_bus(data_bus), .halted(halted));

initial clk = 0;
always #5 clk = ~clk;

integer pass_count = 0, fail_count = 0, test_num = 0;

task check(input [7:0] got, input [7:0] exp, input [255:0] name); begin
    test_num = test_num + 1;
    if (got === exp) begin pass_count = pass_count + 1; $display("PASS %0d: %0s = $%02X", test_num, name, got); end
    else begin fail_count = fail_count + 1; $display("FAIL %0d: %0s got=$%02X exp=$%02X", test_num, name, got, exp); end
end endtask

task run(input integer n); integer i; begin
    for (i = 0; i < n; i = i + 1) @(posedge clk);
end endtask

integer i;
initial begin
    $dumpfile("rv8gr_asm.vcd");
    $dumpvars(0, tb_rv8gr_asm);

    // Load assembled program into CPU's internal ROM
    // (ROM addresses are offset from $8000, so rom[0] = $8000)
    for (i = 0; i < 65536; i = i + 1) uut.rom[i] = 8'h00;
    for (i = 0; i < 256; i = i + 1) uut.ram[i] = 8'h00;

    uut.rom[16'h0000] = 8'h30; uut.rom[16'h0001] = 8'h42; // LI $42
    uut.rom[16'h0002] = 8'h10; uut.rom[16'h0003] = 8'h10; // ADDI $10
    uut.rom[16'h0004] = 8'h90; uut.rom[16'h0005] = 8'h02; // SUBI $02
    uut.rom[16'h0006] = 8'h04; uut.rom[16'h0007] = 8'h03; // MV t0, a0
    uut.rom[16'h0008] = 8'h30; uut.rom[16'h0009] = 8'h0A; // LI $0A
    uut.rom[16'h000A] = 8'h18; uut.rom[16'h000B] = 8'h03; // ADD t0
    uut.rom[16'h000C] = 8'h50; uut.rom[16'h000D] = 8'hFF; // XORI $FF
    uut.rom[16'h000E] = 8'h04; uut.rom[16'h000F] = 8'h03; // MV t0, a0
    uut.rom[16'h0010] = 8'h30; uut.rom[16'h0011] = 8'h00; // LI $00
    uut.rom[16'h0012] = 8'h38; uut.rom[16'h0013] = 8'h03; // MV a0, t0
    uut.rom[16'h0014] = 8'h30; uut.rom[16'h0015] = 8'h25; // LI $25
    uut.rom[16'h0016] = 8'h18; uut.rom[16'h0017] = 8'h01; // SLL
    uut.rom[16'h0018] = 8'h02; uut.rom[16'h0019] = 8'h1E; // BEQ skip1
    uut.rom[16'h001A] = 8'h30; uut.rom[16'h001B] = 8'h01; // LI $01
    uut.rom[16'h001C] = 8'h01; uut.rom[16'h001D] = 8'h20; // J test11
    uut.rom[16'h001E] = 8'h30; uut.rom[16'h001F] = 8'hFF; // skip1 (shouldn't reach)
    uut.rom[16'h0020] = 8'h30; uut.rom[16'h0021] = 8'h00; // test11: LI $00
    uut.rom[16'h0022] = 8'h02; uut.rom[16'h0023] = 8'h26; // BEQ test12
    uut.rom[16'h0024] = 8'h30; uut.rom[16'h0025] = 8'hFF; // shouldn't reach
    uut.rom[16'h0026] = 8'h30; uut.rom[16'h0027] = 8'h03; // test12: LI $03
    uut.rom[16'h0028] = 8'h90; uut.rom[16'h0029] = 8'h01; // loop: SUBI $01
    uut.rom[16'h002A] = 8'h82; uut.rom[16'h002B] = 8'h28; // BNE loop
    uut.rom[16'h002C] = 8'h30; uut.rom[16'h002D] = 8'h77; // test13: LI $77
    uut.rom[16'h002E] = 8'h04; uut.rom[16'h002F] = 8'h20; // SB $20
    uut.rom[16'h0030] = 8'h30; uut.rom[16'h0031] = 8'h00; // LI $00
    uut.rom[16'h0032] = 8'h38; uut.rom[16'h0033] = 8'h20; // LB $20
    uut.rom[16'h0034] = 8'h01; uut.rom[16'h0035] = 8'h34; // HLT

    // Reset and run
    rst_n = 0; #20; rst_n = 1;

    // Run until halted or timeout
    for (i = 0; i < 2000; i = i + 1) begin
        @(posedge clk);
        if (halted) begin
            i = 9999; // break
        end
    end

    // Check final state
    check(uut.ac, 8'h77, "Final AC (LB $20 = $77)");
    check(uut.ram[3], 8'hA5, "RAM[3] (t0 = $A5 from XOR)");
    check(uut.ram[16'h20], 8'h77, "RAM[$20] (stored $77)");

    $display("");
    $display("========================================");
    $display("  RV8-GR Assembly Integration Test");
    $display("  PASS: %0d / %0d", pass_count, test_num);
    if (fail_count > 0) $display("  FAIL: %0d", fail_count);
    else $display("  ALL TESTS PASSED!");
    $display("========================================");
    $finish;
end

endmodule
