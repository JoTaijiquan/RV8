// Testbench for minimal RISC-V CPU
`timescale 1ns/1ps

module tb_riscv_cpu;
    reg clk, rst;

    riscv_cpu CPU (.clk(clk), .rst(rst));

    // Clock: 10ns period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("riscv_cpu.vcd");
        $dumpvars(0, tb_riscv_cpu);

        // Load test program into instruction memory
        // Program:
        //   addi x1, x0, 5      -> x1 = 5
        //   addi x2, x0, 3      -> x2 = 3
        //   add  x3, x1, x2     -> x3 = 8
        //   sub  x4, x1, x2     -> x4 = 2
        //   and  x5, x1, x2     -> x5 = 1
        //   or   x6, x1, x2     -> x6 = 7
        //   sw   x3, 0(x0)      -> mem[0] = 8
        //   lw   x7, 0(x0)      -> x7 = 8
        //   beq  x1, x1, +8     -> skip next instr
        //   addi x8, x0, 99     -> SKIPPED
        //   addi x9, x0, 42     -> x9 = 42

        CPU.IMEM.mem[0]  = 32'h00500093; // addi x1, x0, 5
        CPU.IMEM.mem[1]  = 32'h00300113; // addi x2, x0, 3
        CPU.IMEM.mem[2]  = 32'h002081b3; // add  x3, x1, x2
        CPU.IMEM.mem[3]  = 32'h40208233; // sub  x4, x1, x2
        CPU.IMEM.mem[4]  = 32'h0020f2b3; // and  x5, x1, x2
        CPU.IMEM.mem[5]  = 32'h0020e333; // or   x6, x1, x2
        CPU.IMEM.mem[6]  = 32'h00302023; // sw   x3, 0(x0)
        CPU.IMEM.mem[7]  = 32'h00002383; // lw   x7, 0(x0)
        CPU.IMEM.mem[8]  = 32'h00108463; // beq  x1, x1, +8
        CPU.IMEM.mem[9]  = 32'h06300413; // addi x8, x0, 99
        CPU.IMEM.mem[10] = 32'h02a00493; // addi x9, x0, 42

        clk = 0; rst = 1;
        #12 rst = 0;

        // Run 12 cycles
        #120;

        // Check results
        $display("=== RISC-V CPU Test Results ===");
        $display("x1 = %0d (expect 5)",  CPU.RF.regs[1]);
        $display("x2 = %0d (expect 3)",  CPU.RF.regs[2]);
        $display("x3 = %0d (expect 8)",  CPU.RF.regs[3]);
        $display("x4 = %0d (expect 2)",  CPU.RF.regs[4]);
        $display("x5 = %0d (expect 1)",  CPU.RF.regs[5]);
        $display("x6 = %0d (expect 7)",  CPU.RF.regs[6]);
        $display("x7 = %0d (expect 8)",  CPU.RF.regs[7]);
        $display("x8 = %0d (expect 0)",  CPU.RF.regs[8]);
        $display("x9 = %0d (expect 42)", CPU.RF.regs[9]);

        if (CPU.RF.regs[1] == 5  && CPU.RF.regs[2] == 3 &&
            CPU.RF.regs[3] == 8  && CPU.RF.regs[4] == 2 &&
            CPU.RF.regs[5] == 1  && CPU.RF.regs[6] == 7 &&
            CPU.RF.regs[7] == 8  && CPU.RF.regs[8] == 0 &&
            CPU.RF.regs[9] == 42)
            $display(">>> ALL TESTS PASSED <<<");
        else
            $display(">>> SOME TESTS FAILED <<<");

        $finish;
    end
endmodule
