`timescale 1ns / 1ps
// RV8-G — Gates-Only 8-bit CPU (22 chips, 25 instructions, no EEPROM)
// Opcode bits wire directly to control — minimal decode logic

module rv8g_cpu (
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

// --- State machine (2 flip-flops = 4 states) ---
reg [1:0] state;
localparam S0 = 2'd0; // Fetch opcode
localparam S1 = 2'd1; // Fetch operand
localparam S2 = 2'd2; // Execute
localparam S3 = 2'd3; // Memory access (if needed)

// --- Registers ---
reg [15:0] pc;
reg [7:0]  ir_op, ir_opr;
reg [7:0]  a0, t0, sp;
reg [7:0]  pl, ph;
reg        flag_z, flag_c, flag_n, flag_ie;

// --- Instruction decode (direct from opcode bits) ---
wire [1:0] iclass = ir_op[7:6];  // 00=ALU, 01=LDST, 10=Branch, 11=System
wire [2:0] op     = ir_op[5:3];  // operation within class
wire [2:0] modf   = ir_op[2:0];  // modifier/register select

// --- ALU ---
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
            3'd5: alu_calc = {1'b0, a} - {1'b0, b};       // CMP (same as SUB, no store)
            3'd6: alu_calc = {1'b0, a} + 9'd1;            // INC
            3'd7: alu_calc = {1'b0, a} - 9'd1;            // DEC / MOV(pass b)
            default: alu_calc = 9'd0;
        endcase
    end
endfunction

// --- Address output ---
reg [15:0] addr_r;
reg        rd_r, wr_r;
reg [7:0]  dout_r;
assign addr = addr_r;
assign data_out = dout_r;
assign mem_rd = rd_r;
assign mem_wr = wr_r;

// --- Main logic ---
reg [8:0] alu_result;
reg need_s3; // does this instruction need memory access in S3?

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S0;
        pc <= 16'hC000; // reset vector (ROM start)
        a0 <= 8'd0; t0 <= 8'd0; sp <= 8'hFF;
        pl <= 8'd0; ph <= 8'd0;
        ir_op <= 8'd0; ir_opr <= 8'd0;
        flag_z <= 0; flag_c <= 0; flag_n <= 0; flag_ie <= 0;
        rd_r <= 0; wr_r <= 0;
        addr_r <= 16'd0; dout_r <= 8'd0;
        need_s3 <= 0;
    end else begin
        rd_r <= 0;
        wr_r <= 0;

        case (state)
        // ===== S0: Fetch opcode =====
        S0: begin
            addr_r <= pc;
            rd_r <= 1;
            state <= S1;
        end

        // ===== S1: Latch opcode, fetch operand =====
        S1: begin
            ir_op <= data_in;
            pc <= pc + 16'd1;
            addr_r <= pc + 16'd1;
            rd_r <= 1;
            state <= S2;
        end

        // ===== S2: Latch operand, execute =====
        S2: begin
            ir_opr <= data_in;
            pc <= pc + 16'd1;
            need_s3 <= 0;

            case (ir_op[7:6])
            // --- Class 00: ALU ---
            2'b00: begin
                if (ir_op[0]) // immediate mode
                    alu_result = alu_calc(a0, data_in, ir_op[5:3]);
                else // register mode (t0)
                    alu_result = alu_calc(a0, t0, ir_op[5:3]);

                // Special: op=7, modf[0]=1 → MOV t0,a0 (pass)
                if (ir_op[5:3] == 3'd7 && ir_op[0]) begin
                    t0 <= a0; // MOV t0, a0
                end else if (ir_op[5:3] != 3'd5) begin // not CMP
                    a0 <= alu_result[7:0];
                end
                flag_z <= (alu_result[7:0] == 8'd0);
                flag_c <= alu_result[8];
                flag_n <= alu_result[7];
                state <= S0;
            end

            // --- Class 01: Load/Store ---
            2'b01: begin
                case (ir_op[5:3])
                    3'd0: begin // LI reg, imm
                        case (ir_op[2:0])
                            3'd0: begin a0 <= data_in; flag_z <= (data_in==8'd0); flag_n <= data_in[7]; end
                            3'd1: t0 <= data_in;
                            3'd2: sp <= data_in;
                            3'd3: pl <= data_in;
                            3'd4: ph <= data_in;
                            default: ;
                        endcase
                        state <= S0;
                    end
                    3'd1: begin // LB (ptr)
                        addr_r <= {ph, pl};
                        rd_r <= 1;
                        need_s3 <= 1;
                        state <= S3;
                    end
                    3'd2: begin // SB (ptr)
                        addr_r <= {ph, pl};
                        dout_r <= a0;
                        wr_r <= 1;
                        need_s3 <= 1;
                        state <= S3;
                    end
                    3'd3: begin // LB zp:imm
                        addr_r <= {8'h00, data_in};
                        rd_r <= 1;
                        need_s3 <= 1;
                        state <= S3;
                    end
                    3'd4: begin // SB zp:imm
                        addr_r <= {8'h00, data_in};
                        dout_r <= a0;
                        wr_r <= 1;
                        need_s3 <= 1;
                        state <= S3;
                    end
                    3'd5: begin // LB (ptr+) — load and increment pointer
                        addr_r <= {ph, pl};
                        rd_r <= 1;
                        {ph, pl} <= {ph, pl} + 16'd1;
                        need_s3 <= 1;
                        state <= S3;
                    end
                    default: state <= S0;
                endcase
            end

            // --- Class 10: Branch/Jump ---
            2'b10: begin
                case (ir_op[5:3])
                    3'd0: if (flag_z)  pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    3'd1: if (!flag_z) pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    3'd2: if (flag_c)  pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    3'd3: if (!flag_c) pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    3'd4: if (flag_n)  pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    3'd5: if (!flag_n) pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in};
                    3'd6: pc <= pc + 16'd1 + {{8{data_in[7]}}, data_in}; // BRA
                    3'd7: pc <= {ph, data_in}; // JMP absolute
                endcase
                if (ir_op[5:3] != 3'd7 && !(
                    (ir_op[5:3]==3'd0 && flag_z) || (ir_op[5:3]==3'd1 && !flag_z) ||
                    (ir_op[5:3]==3'd2 && flag_c) || (ir_op[5:3]==3'd3 && !flag_c) ||
                    (ir_op[5:3]==3'd4 && flag_n) || (ir_op[5:3]==3'd5 && !flag_n) ||
                    (ir_op[5:3]==3'd6)))
                    pc <= pc + 16'd1; // not taken: normal increment
                state <= S0;
            end

            // --- Class 11: System ---
            2'b11: begin
                case (ir_op[5:3])
                    3'd0: begin // PUSH a0
                        sp <= sp - 8'd1;
                        addr_r <= {8'h30, sp - 8'd1};
                        dout_r <= a0;
                        wr_r <= 1;
                        need_s3 <= 1;
                        state <= S3;
                    end
                    3'd1: begin // POP a0
                        addr_r <= {8'h30, sp};
                        rd_r <= 1;
                        sp <= sp + 8'd1;
                        need_s3 <= 1;
                        state <= S3;
                    end
                    3'd2: begin // CALL imm — push PC low, jump to {ph, imm}
                        sp <= sp - 8'd1;
                        addr_r <= {8'h30, sp - 8'd1};
                        dout_r <= pc[7:0]; // push PCL only (8-bit return)
                        wr_r <= 1;
                        pc <= {ph, data_in}; // jump
                        need_s3 <= 1;
                        state <= S3;
                    end
                    3'd3: begin // RET — pop PCL, keep PCH
                        addr_r <= {8'h30, sp};
                        rd_r <= 1;
                        sp <= sp + 8'd1;
                        need_s3 <= 1;
                        state <= S3;
                    end
                    3'd4: ; // NOP
                    3'd5: begin // HLT
                        pc <= pc - 16'd1; // re-fetch HLT (override the +1)
                    end
                    3'd6: flag_ie <= 1'b1; // EI
                    3'd7: flag_ie <= 1'b0; // DI
                endcase
                if (ir_op[5:3] >= 3'd4)
                    state <= S0;
            end
            endcase
        end

        // ===== S3: Memory read/write complete =====
        S3: begin
            case (ir_op[7:6])
            2'b01: begin // Load/Store class
                if (ir_op[5:3] == 3'd1 || ir_op[5:3] == 3'd3 || ir_op[5:3] == 3'd5) begin
                    // LB: latch data
                    a0 <= data_in;
                    flag_z <= (data_in == 8'd0);
                    flag_n <= data_in[7];
                end
            end
            2'b11: begin // System class
                case (ir_op[5:3])
                    3'd1: begin // POP complete
                        a0 <= data_in;
                    end
                    3'd2: begin // CALL: write already done in S2, just finish
                    end
                    3'd3: begin // RET: got PCL
                        pc <= {ph, data_in}; // return to {ph, popped_byte}
                    end
                    default: ;
                endcase
            end
            default: ;
            endcase
            state <= S0;
        end
        endcase
    end
end

endmodule
