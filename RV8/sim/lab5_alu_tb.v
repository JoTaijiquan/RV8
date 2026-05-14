// Lab 5: ALU — Simulation
// Run: iverilog -o lab5 lab5_alu_tb.v && vvp lab5
`timescale 1ns/1ns

module lab5_alu_tb;
    reg [7:0] a, b;
    reg sub;
    wire [7:0] result;
    wire carry;

    // 74HC283 x2 + 74HC86 model
    wire [7:0] b_xor = b ^ {8{sub}};
    wire [8:0] sum = a + b_xor + sub;
    assign result = sum[7:0];
    assign carry = sum[8];

    integer pass = 0, fail = 0;

    task check(input [7:0] exp_r, input exp_c);
    begin
        #1;
        if (result == exp_r && carry == exp_c) begin
            $display("  PASS: %02X %s %02X = %02X, C=%b",
                     a, sub ? "-" : "+", b, result, carry);
            pass = pass + 1;
        end else begin
            $display("  FAIL: %02X %s %02X = %02X (expect %02X), C=%b (expect %b)",
                     a, sub ? "-" : "+", b, result, exp_r, carry, exp_c);
            fail = fail + 1;
        end
    end
    endtask

    initial begin
        $dumpfile("lab5.vcd"); $dumpvars(0, lab5_alu_tb);
        $display("=== Lab 5: ALU ===");

        // ADD tests
        sub=0; a= 8'h05; b= 8'h03; check(8'h08, 0);
        sub=0; a= 8'hFF; b= 8'h01; check(8'h00, 1);
        sub=0; a= 8'h80; b= 8'h80; check(8'h00, 1);
        sub=0; a= 8'hAA; b= 8'h55; check(8'hFF, 0);
        sub=0; a= 8'hFF; b= 8'hFF; check(8'hFE, 1);
        sub=0; a= 8'h00; b= 8'h00; check(8'h00, 0);

        // SUB tests
        sub=1; a= 8'h05; b= 8'h03; check(8'h02, 1);
        sub=1; a= 8'h03; b= 8'h05; check(8'hFE, 0);
        sub=1; a= 8'h00; b= 8'h01; check(8'hFF, 0);
        sub=1; a= 8'h80; b= 8'h01; check(8'h7F, 1);
        sub=1; a= 8'hFF; b= 8'hFF; check(8'h00, 1);

        $display("Results: %0d passed, %0d failed", pass, fail);
        if (fail == 0) $display("Lab 5 PASSED");
        else $display("Lab 5 FAILED");
        $finish;
    end
endmodule
