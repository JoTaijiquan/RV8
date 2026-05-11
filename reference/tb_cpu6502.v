// Testbench for cpu6502
`timescale 1ns/1ps
module tb_cpu6502;

reg        clk, rst_n, irq_n, nmi_n;
wire [15:0] addr;
wire [7:0]  data;
wire        rw;

// 64KB RAM
reg [7:0] mem [0:65535];

// Drive data bus on reads
assign data = rw ? mem[addr] : 8'bz;

// Write on falling edge when rw=0
always @(negedge clk)
    if (!rw) mem[addr] <= data;

cpu6502 dut(
    .clk(clk), .rst_n(rst_n),
    .irq_n(irq_n), .nmi_n(nmi_n),
    .addr(addr), .data(data), .rw(rw)
);

always #5 clk = ~clk;

integer i;
initial begin
    clk=0; rst_n=0; irq_n=1; nmi_n=1;

    // Zero memory
    for (i=0; i<65536; i=i+1) mem[i]=8'h00;

    // Reset vector -> $0200
    mem[16'hFFFC] = 8'h00;
    mem[16'hFFFD] = 8'h02;

    // Simple program at $0200:
    //   LDA #$42   A9 42
    //   LDX #$10   A2 10
    //   LDY #$20   A0 20
    //   TAX        AA
    //   TAY        A8
    //   CLC        18
    //   ADC #$01   69 01
    //   STA $0300  8D 00 03
    //   NOP        EA
    //   BRK        00
    mem[16'h0200]=8'hA9; mem[16'h0201]=8'h42;
    mem[16'h0202]=8'hA2; mem[16'h0203]=8'h10;
    mem[16'h0204]=8'hA0; mem[16'h0205]=8'h20;
    mem[16'h0206]=8'hAA;
    mem[16'h0207]=8'hA8;
    mem[16'h0208]=8'h18;
    mem[16'h0209]=8'h69; mem[16'h020A]=8'h01;
    mem[16'h020B]=8'h8D; mem[16'h020C]=8'h00; mem[16'h020D]=8'h03;
    mem[16'h020E]=8'hEA;
    mem[16'h020F]=8'h00;

    // IRQ vector -> $0300 (just NOPs)
    mem[16'hFFFE]=8'h00; mem[16'hFFFF]=8'h03;
    mem[16'h0300]=8'hEA; mem[16'h0301]=8'hEA;

    @(posedge clk); @(posedge clk);
    rst_n = 1;

    // Run 200 cycles
    repeat(200) @(posedge clk);

    // Check result
    if (mem[16'h0300] === 8'h43)
        $display("PASS: mem[$0300] = $43 (A=$42 + 1)");
    else
        $display("FAIL: mem[$0300] = %02X (expected $43)", mem[16'h0300]);

    $finish;
end

// Timeout
initial begin
    #10000;
    $display("TIMEOUT");
    $finish;
end

endmodule
