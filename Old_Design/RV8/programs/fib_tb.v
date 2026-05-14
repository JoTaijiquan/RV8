// RV8 Demo Testbench — Runs Fibonacci program
`timescale 1ns / 1ps
module fib_tb;
    reg clk, rst_n;
    wire [15:0] addr_bus;
    wire [7:0] data_bus;
    wire mem_rd_n, mem_wr_n, halt;
    reg [7:0] mem [0:65535];
    assign data_bus = (!mem_rd_n) ? mem[addr_bus] : 8'bz;
    rv8_cpu CPU(.clk(clk),.rst_n(rst_n),.nmi_n(1'b1),.irq_n(1'b1),
        .addr_bus(addr_bus),.data_bus(data_bus),.mem_rd_n(mem_rd_n),.mem_wr_n(mem_wr_n),.halt(halt));
    always @(posedge clk) if(!mem_wr_n) mem[addr_bus] <= data_bus;
    initial clk=0; always #5 clk=~clk;

    integer i;
    initial begin
        $dumpfile("fib.vcd"); $dumpvars(0, fib_tb);
        // Init memory
        for(i=0; i<65536; i=i+1) mem[i] = 8'hFF;
        // Load program (assembled bytes)
        mem[16'hC000] = 8'h13; mem[16'hC001] = 8'h20; // li ph, $20
        mem[16'hC002] = 8'h12; mem[16'hC003] = 8'h00; // li pl, $00
        mem[16'hC004] = 8'h11; mem[16'hC005] = 8'h00; // li a0, 0
        mem[16'hC006] = 8'h23; mem[16'hC007] = 8'h00; // sb (ptr+)
        mem[16'hC008] = 8'h11; mem[16'hC009] = 8'h01; // li a0, 1
        mem[16'hC00A] = 8'h23; mem[16'hC00B] = 8'h00; // sb (ptr+)
        mem[16'hC00C] = 8'h11; mem[16'hC00D] = 8'h09; // li a0, 9
        mem[16'hC00E] = 8'h29; mem[16'hC00F] = 8'h10; // sb.zp $10
        // loop:
        mem[16'hC010] = 8'h49; mem[16'hC011] = 8'h00; // dec16
        mem[16'hC012] = 8'h20; mem[16'hC013] = 8'h00; // lb a0, (ptr)
        mem[16'hC014] = 8'h24; mem[16'hC015] = 8'h05; // mov t0, a0
        mem[16'hC016] = 8'h49; mem[16'hC017] = 8'h00; // dec16
        mem[16'hC018] = 8'h20; mem[16'hC019] = 8'h00; // lb a0, (ptr)
        mem[16'hC01A] = 8'h00; mem[16'hC01B] = 8'h05; // add t0
        mem[16'hC01C] = 8'h48; mem[16'hC01D] = 8'h00; // inc16
        mem[16'hC01E] = 8'h48; mem[16'hC01F] = 8'h00; // inc16
        mem[16'hC020] = 8'h23; mem[16'hC021] = 8'h00; // sb (ptr+)
        mem[16'hC022] = 8'h28; mem[16'hC023] = 8'h10; // lb.zp $10
        mem[16'hC024] = 8'h17; mem[16'hC025] = 8'h01; // subi 1
        mem[16'hC026] = 8'h29; mem[16'hC027] = 8'h10; // sb.zp $10
        mem[16'hC028] = 8'h31; mem[16'hC029] = 8'hE6; // bne loop (-26 = 0xE6)
        mem[16'hC02A] = 8'hFF; mem[16'hC02B] = 8'h00; // hlt
        // Reset vector
        mem[16'hFFFC] = 8'h00; mem[16'hFFFD] = 8'hC0;

        // Run
        rst_n = 0; #30; rst_n = 1;
        wait(halt); #10;

        // Print results
        $display("Fibonacci sequence at 0x2000:");
        $display("  fib[0]  = %d", mem[16'h2000]);
        $display("  fib[1]  = %d", mem[16'h2001]);
        $display("  fib[2]  = %d", mem[16'h2002]);
        $display("  fib[3]  = %d", mem[16'h2003]);
        $display("  fib[4]  = %d", mem[16'h2004]);
        $display("  fib[5]  = %d", mem[16'h2005]);
        $display("  fib[6]  = %d", mem[16'h2006]);
        $display("  fib[7]  = %d", mem[16'h2007]);
        $display("  fib[8]  = %d", mem[16'h2008]);
        $display("  fib[9]  = %d", mem[16'h2009]);
        $display("  fib[10] = %d", mem[16'h200A]);

        // Verify
        if(mem[16'h2000]==0 && mem[16'h2001]==1 && mem[16'h2002]==1 &&
           mem[16'h2003]==2 && mem[16'h2004]==3 && mem[16'h2005]==5 &&
           mem[16'h2006]==8 && mem[16'h2007]==13 && mem[16'h2008]==21 &&
           mem[16'h2009]==34 && mem[16'h200A]==55)
            $display("\n*** FIBONACCI CORRECT! ***");
        else
            $display("\n*** FIBONACCI FAILED ***");

        $finish;
    end
    initial begin #500000; $display("TIMEOUT"); $finish; end
endmodule
