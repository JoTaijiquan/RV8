`timescale 1ns / 1ps
// RV802 — RISC-V Style 8-bit CPU
// 23 chips, 8 registers, single-bus, Flash microcode (behavioral)

module rv802_cpu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        nmi_n,
    input  wire        irq_n,
    output wire [15:0] addr,
    output wire [7:0]  data_out,
    input  wire [7:0]  data_in,
    output wire        mem_rd,
    output wire        mem_wr
);

// --- Registers (8 × 8-bit) ---
reg [7:0] r [0:7]; // r0=zero, r1-r6=general, r7=sp
reg [15:0] pc;
reg [7:0] ir_op, ir_opr;
reg flag_z, flag_c;

// --- State ---
reg [2:0] state;
localparam S_F0 = 3'd0; // fetch opcode
localparam S_F1 = 3'd1; // fetch operand
localparam S_EX = 3'd2; // execute (immediate ALU, branch, LI)
localparam S_RS = 3'd3; // load rs into temp (for reg-reg ops)
localparam S_M1 = 3'd4; // memory address setup + read/write
localparam S_M2 = 3'd5; // memory data latch

// --- Decode ---
wire [1:0] iclass = ir_op[7:6];
wire [2:0] op = ir_op[5:3];
wire [2:0] rd = ir_op[2:0];
wire [2:0] rs = ir_opr[7:5];
wire [4:0] off5 = ir_opr[4:0];

// --- ALU ---
reg [7:0] alu_b_latch; // holds rs value for reg-reg ops
reg [8:0] alu_result;

function [8:0] alu_calc;
    input [7:0] a, b;
    input [2:0] op;
    begin
        case (op)
            3'd0: alu_calc = {1'b0, a} + {1'b0, b};       // ADD
            3'd1: alu_calc = {1'b0, a} - {1'b0, b};       // SUB
            3'd2: alu_calc = {1'b0, a & b};                // AND
            3'd3: alu_calc = {1'b0, a | b};                // OR
            3'd4: alu_calc = {1'b0, a ^ b};                // XOR
            3'd5: alu_calc = {1'b0, a} - {1'b0, b};       // CMP/SLT
            3'd6: alu_calc = {a[7], a[6:0], 1'b0};        // SHL
            3'd7: alu_calc = {a[0], 1'b0, a[7:1]};        // SHR
            default: alu_calc = 9'd0;
        endcase
    end
endfunction

// --- Output ---
reg [15:0] addr_r;
reg [7:0] dout_r;
reg rd_r, wr_r;
assign addr = addr_r;
assign data_out = dout_r;
assign mem_rd = rd_r;
assign mem_wr = wr_r;

// --- Main ---
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_F0;
        pc <= 16'hC000;
        ir_op <= 0; ir_opr <= 0;
        flag_z <= 0; flag_c <= 0;
        alu_b_latch <= 0;
        addr_r <= 0; dout_r <= 0; rd_r <= 0; wr_r <= 0;
        for (i = 0; i < 8; i = i + 1) r[i] = 8'd0;
    end else begin
        rd_r <= 0; wr_r <= 0;
        // r0 always zero
        r[0] <= 8'd0;

        case (state)
        S_F0: begin
            addr_r <= pc;
            rd_r <= 1;
            state <= S_F1;
        end

        S_F1: begin
            ir_op <= data_in;
            pc <= pc + 16'd1;
            addr_r <= pc + 16'd1;
            rd_r <= 1;
            state <= S_EX;
        end

        S_EX: begin
            ir_opr <= data_in;
            pc <= pc + 16'd1;

            case (ir_op[7:6])
            // === Class 00: ALU register-register ===
            2'b00: begin
                // Need rs value — go to S_RS to load it
                alu_b_latch <= r[data_in[7:5]]; // rs from operand[7:5]
                state <= S_RS;
            end

            // === Class 01: Immediate ===
            2'b01: begin
                case (op)
                    3'd0: r[rd] <= data_in; // LI
                    3'd1: begin alu_result = alu_calc(r[rd], data_in, 3'd0); r[rd] <= alu_result[7:0]; flag_z <= (alu_result[7:0]==0); flag_c <= alu_result[8]; end // ADDI
                    3'd2: begin alu_result = alu_calc(r[rd], data_in, 3'd1); r[rd] <= alu_result[7:0]; flag_z <= (alu_result[7:0]==0); flag_c <= alu_result[8]; end // SUBI
                    3'd3: begin alu_result = alu_calc(r[rd], data_in, 3'd2); r[rd] <= alu_result[7:0]; flag_z <= (alu_result[7:0]==0); flag_c <= alu_result[8]; end // ANDI
                    3'd4: begin alu_result = alu_calc(r[rd], data_in, 3'd3); r[rd] <= alu_result[7:0]; flag_z <= (alu_result[7:0]==0); flag_c <= alu_result[8]; end // ORI
                    3'd5: begin alu_result = alu_calc(r[rd], data_in, 3'd4); r[rd] <= alu_result[7:0]; flag_z <= (alu_result[7:0]==0); flag_c <= alu_result[8]; end // XORI
                    3'd6: begin alu_result = alu_calc(r[rd], data_in, 3'd5); flag_z <= (alu_result[7:0]==0); flag_c <= alu_result[8]; end // CMPI (no store)
                    3'd7: r[rd] <= {data_in[3:0], 4'b0000}; // LUI (load upper nibble)
                endcase
                state <= S_F0;
            end

            // === Class 10: Memory ===
            2'b10: begin
                case (op)
                    3'd0: begin // LB rd, [rs+off5]
                        addr_r <= {8'h00, r[data_in[7:5]]} + {{11{data_in[4]}}, data_in[4:0]};
                        rd_r <= 1;
                        state <= S_M2;
                    end
                    3'd1: begin // SB rd, [rs+off5]
                        addr_r <= {8'h00, r[data_in[7:5]]} + {{11{data_in[4]}}, data_in[4:0]};
                        dout_r <= r[rd];
                        wr_r <= 1;
                        state <= S_M2;
                    end
                    3'd2: begin // LB rd, [imm8] (zero-page)
                        addr_r <= {8'h00, data_in};
                        rd_r <= 1;
                        state <= S_M2;
                    end
                    3'd3: begin // SB rd, [imm8] (zero-page)
                        addr_r <= {8'h00, data_in};
                        dout_r <= r[rd];
                        wr_r <= 1;
                        state <= S_M2;
                    end
                    3'd4: begin // PUSH rd
                        r[7] <= r[7] - 8'd1;
                        addr_r <= {8'h30, r[7] - 8'd1};
                        dout_r <= r[rd];
                        wr_r <= 1;
                        state <= S_M2;
                    end
                    3'd5: begin // POP rd
                        addr_r <= {8'h30, r[7]};
                        rd_r <= 1;
                        r[7] <= r[7] + 8'd1;
                        state <= S_M2;
                    end
                    3'd6: begin // LW rd, [sp+off] (stack local)
                        addr_r <= {8'h30, r[7] + data_in};
                        rd_r <= 1;
                        state <= S_M2;
                    end
                    3'd7: begin // SW rd, [sp+off] (stack local)
                        addr_r <= {8'h30, r[7] + data_in};
                        dout_r <= r[rd];
                        wr_r <= 1;
                        state <= S_M2;
                    end
                endcase
            end

            // === Class 11: Control ===
            2'b11: begin
                case (op)
                    3'd0: begin // BEQ
                        if (flag_z) pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    end
                    3'd1: begin // BNE
                        if (!flag_z) pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    end
                    3'd2: begin // BCS
                        if (flag_c) pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    end
                    3'd3: begin // BCC
                        if (!flag_c) pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    end
                    3'd4: begin // BRA
                        pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    end
                    3'd5: begin // JAL rd, off8
                        r[rd] <= pc[7:0]; // save return address (low byte)
                        pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    end
                    3'd6: begin // JMP imm8 (PC ← {r6, imm8})
                        pc <= {r[6], data_in};
                    end
                    3'd7: begin // SYS (sub-decode from operand)
                        case (data_in)
                            8'h00: ; // NOP
                            8'h01: pc <= pc - 16'd2; // HLT (loop)
                            8'h02: ; // EI (TODO)
                            8'h03: ; // DI (TODO)
                            default: ;
                        endcase
                    end
                endcase
                state <= S_F0;
            end
            endcase
        end

        // === S_RS: Execute reg-reg ALU ===
        S_RS: begin
            case (op)
                3'd0: alu_result = alu_calc(r[rd], alu_b_latch, 3'd0); // ADD
                3'd1: alu_result = alu_calc(r[rd], alu_b_latch, 3'd1); // SUB
                3'd2: alu_result = alu_calc(r[rd], alu_b_latch, 3'd2); // AND
                3'd3: alu_result = alu_calc(r[rd], alu_b_latch, 3'd3); // OR
                3'd4: alu_result = alu_calc(r[rd], alu_b_latch, 3'd4); // XOR
                3'd5: alu_result = alu_calc(r[rd], alu_b_latch, 3'd5); // CMP/SLT
                3'd6: alu_result = alu_calc(r[rd], 8'd0, 3'd6);        // SHL
                3'd7: alu_result = alu_calc(r[rd], 8'd0, 3'd7);        // SHR
            endcase
            if (op == 3'd5) begin // SLT: rd ← (rd < rs) ? 1 : 0
                r[rd] <= alu_result[8] ? 8'd1 : 8'd0; // carry=borrow=less-than
            end else if (op != 3'd5) begin
                r[rd] <= alu_result[7:0];
            end
            flag_z <= (alu_result[7:0] == 8'd0);
            flag_c <= alu_result[8];
            state <= S_F0;
        end

        // === S_M2: Memory complete ===
        S_M2: begin
            // If it was a read, latch data into rd
            if (ir_op[5:3] == 3'd0 || ir_op[5:3] == 3'd2 ||
                ir_op[5:3] == 3'd5 || ir_op[5:3] == 3'd6) begin
                r[rd] <= data_in;
            end
            state <= S_F0;
        end

        default: state <= S_F0;
        endcase
    end
end

endmodule
