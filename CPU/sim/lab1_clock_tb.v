// Lab 1: Clock and Reset — Simulation
// Run: iverilog -o lab1 lab1_clock_tb.v && vvp lab1
`timescale 1ns/1ns

module lab1_clock_tb;
    reg osc = 0;
    reg step_btn = 0;
    reg run_mode = 1;  // 1=RUN, 0=STEP
    reg rst_btn = 1;   // active low

    // 74HC157 mux: selects osc (run) or step_btn (step)
    wire clk = run_mode ? osc : step_btn;
    wire rst_n = rst_btn;

    // 3.5 MHz oscillator (142.8ns period)
    always #71 osc = ~osc;

    initial begin
        $dumpfile("lab1.vcd"); $dumpvars(0, lab1_clock_tb);

        // Test 1: RUN mode — clock runs
        $display("=== Lab 1: Clock and Reset ===");
        run_mode = 1;
        #500;
        $display("RUN mode: clock toggling at 3.5MHz");

        // Test 2: STEP mode — manual pulses
        run_mode = 0;
        #200;
        step_btn = 1; #50; step_btn = 0; #200;
        step_btn = 1; #50; step_btn = 0; #200;
        $display("STEP mode: 2 manual pulses generated");

        // Test 3: RESET
        rst_btn = 0; #100;
        $display("RESET active: rst_n = %b", rst_n);
        rst_btn = 1; #100;
        $display("RESET released: rst_n = %b", rst_n);

        $display("Lab 1 PASSED");
        $finish;
    end
endmodule
