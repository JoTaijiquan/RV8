`timescale 1ns / 1ps
// RV808 — 23-chip Harvard 8-bit CPU
// Behavioral Verilog model
// Architecture: internal ROM fetch + paged data RAM + expansion bus

module rv808_cpu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        nmi_n,
    input  wire        irq_n,
    // Code memory interface (internal ROM/RAM)
    output wire [14:0] code_addr,
    input  wire [7:0]  code_data,
    // Data memory interface (paged)
    output wire [15:0] data_addr,
    output wire [7:0]  data_out,
    input  wire [7:0]  data_in,
    output wire        data_rd,
    output wire        data_wr,
    output wire        pg_wr
);

// --- Registers ---
reg [15:0] pc;
reg [7:0]  ir_op, ir_opr;
reg [7:0]  a0, t0, sp, pg;
reg        flag_z, flag_c, flag_n, flag_ie;
reg        skip_flag;
reg        ram_exec; // fetch from RAM when PC >= $4000

// --- State machine ---
localparam S_F0   = 4'd0;  // fetch opcode
localparam S_F1   = 4'd1;  // fetch operand
localparam S_EX   = 4'd2;  // execute
localparam S_M1   = 4'd3;  // memory read
localparam S_M2   = 4'd4;  // memory write
localparam S_S1   = 4'd5;  // stack push
localparam S_S2   = 4'd6;  // stack pop
localparam S_S3   = 4'd7;  // push PCH (JAL/INT)
localparam S_S4   = 4'd8;  // push PCL (JAL/INT)
localparam S_INT  = 4'd9;  // interrupt entry

reg [3:0] state, next_state;
reg [2:0] sub_state; // for multi-step ops (JAL, RET, TRAP, RTI)

// --- ALU ---
reg [8:0] alu_result;

localparam ALU_ADD = 4'd0;
localparam ALU_SUB = 4'd1;
localparam ALU_AND = 4'd2;
localparam ALU_OR  = 4'd3;
localparam ALU_XOR = 4'd4;
localparam ALU_ADC = 4'd5;
localparam ALU_SBC = 4'd6;
localparam ALU_SHL = 4'd7;
localparam ALU_SHR = 4'd8;
localparam ALU_ROL = 4'd9;
localparam ALU_ROR = 4'd10;
localparam ALU_INC = 4'd11;
localparam ALU_DEC = 4'd12;
localparam ALU_NOT = 4'd13;
localparam ALU_SWAP= 4'd14;
localparam ALU_PASS= 4'd15; // pass B through

// --- Instruction decode ---
wire [2:0] unit = ir_op[7:5];
wire [4:0] op   = ir_op[4:0];

// --- Code address output ---
assign code_addr = pc[14:0];

// --- Data address output ---
reg [15:0] daddr;
reg        drd, dwr, dpgwr;
reg [7:0]  dout;
assign data_addr = daddr;
assign data_out  = dout;
assign data_rd   = drd;
assign data_wr   = dwr;
assign pg_wr     = dpgwr;

// --- ALU computation ---
function [8:0] alu_calc;
    input [7:0] a, b;
    input [3:0] op;
    input       ci;
    begin
        case (op)
            ALU_ADD:  alu_calc = {1'b0, a} + {1'b0, b};
            ALU_SUB:  alu_calc = {1'b0, a} - {1'b0, b};
            ALU_AND:  alu_calc = {1'b0, a & b};
            ALU_OR:   alu_calc = {1'b0, a | b};
            ALU_XOR:  alu_calc = {1'b0, a ^ b};
            ALU_ADC:  alu_calc = {1'b0, a} + {1'b0, b} + {8'd0, ci};
            ALU_SBC:  alu_calc = {1'b0, a} - {1'b0, b} - {8'd0, ~ci};
            ALU_SHL:  alu_calc = {a, 1'b0};
            ALU_SHR:  alu_calc = {a[0], 1'b0, a[7:1]};
            ALU_ROL:  alu_calc = {a, ci};
            ALU_ROR:  alu_calc = {a[0], ci, a[7:1]};
            ALU_INC:  alu_calc = {1'b0, a} + 9'd1;
            ALU_DEC:  alu_calc = {1'b0, a} - 9'd1;
            ALU_NOT:  alu_calc = {1'b0, ~a};
            ALU_SWAP: alu_calc = {1'b0, a[3:0], a[7:4]};
            ALU_PASS: alu_calc = {1'b0, b};
            default:  alu_calc = {1'b0, a};
        endcase
    end
endfunction

// --- NMI edge detect ---
reg nmi_prev;
reg nmi_pending;

// --- Main state machine ---
reg [7:0] push_data;
reg [15:0] vector_addr;
reg doing_int; // in interrupt sequence
reg [1:0] int_type; // 0=IRQ, 1=NMI, 2=TRAP

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc <= 16'h0000;
        state <= S_F0;
        sub_state <= 3'd0;
        a0 <= 8'd0; t0 <= 8'd0; sp <= 8'd0; pg <= 8'd0;
        ir_op <= 8'd0; ir_opr <= 8'd0;
        flag_z <= 1'b0; flag_c <= 1'b0; flag_n <= 1'b0; flag_ie <= 1'b0;
        skip_flag <= 1'b0;
        ram_exec <= 1'b0;
        drd <= 1'b0; dwr <= 1'b0; dpgwr <= 1'b0;
        daddr <= 16'd0; dout <= 8'd0;
        doing_int <= 1'b0; int_type <= 2'd0;
        nmi_prev <= 1'b1; nmi_pending <= 1'b0;
    end else begin
        // NMI edge detect
        nmi_prev <= nmi_n;
        if (nmi_prev && !nmi_n)
            nmi_pending <= 1'b1;

        // defaults
        drd <= 1'b0;
        dwr <= 1'b0;
        dpgwr <= 1'b0;

        case (state)
        // ===================== FETCH OPCODE =====================
        S_F0: begin
            ir_op <= code_data;
            pc <= pc + 16'd1;
            state <= S_F1;
        end

        // ===================== FETCH OPERAND =====================
        S_F1: begin
            ir_opr <= code_data;
            pc <= pc + 16'd1;
            // Check for interrupts before execute
            if (nmi_pending && !doing_int) begin
                state <= S_INT;
                sub_state <= 3'd0;
                int_type <= 2'd1; // NMI
                doing_int <= 1'b1;
            end else if (!irq_n && flag_ie && !doing_int) begin
                state <= S_INT;
                sub_state <= 3'd0;
                int_type <= 2'd0; // IRQ
                doing_int <= 1'b1;
            end else begin
                state <= S_EX;
            end
        end

        // ===================== EXECUTE =====================
        S_EX: begin
            if (skip_flag) begin
                // Skip this instruction
                skip_flag <= 1'b0;
                state <= S_F0;
            end else begin
                state <= S_F0; // default: go to next fetch
                case (unit)
                // --- Unit 0: ALU register ---
                3'b000: begin
                    case (op[2:0])
                        3'd0: alu_result = alu_calc(a0, t0, ALU_ADD, flag_c);
                        3'd1: alu_result = alu_calc(a0, t0, ALU_SUB, flag_c);
                        3'd2: alu_result = alu_calc(a0, t0, ALU_AND, flag_c);
                        3'd3: alu_result = alu_calc(a0, t0, ALU_OR,  flag_c);
                        3'd4: alu_result = alu_calc(a0, t0, ALU_XOR, flag_c);
                        3'd5: alu_result = alu_calc(a0, t0, ALU_SUB, flag_c); // CMP
                        3'd6: alu_result = alu_calc(a0, t0, ALU_ADC, flag_c);
                        3'd7: alu_result = alu_calc(a0, t0, ALU_SBC, flag_c);
                    endcase
                    if (op[2:0] != 3'd5) // not CMP
                        a0 <= alu_result[7:0];
                    flag_z <= (alu_result[7:0] == 8'd0);
                    flag_c <= alu_result[8];
                    flag_n <= alu_result[7];
                end

                // --- Unit 1: ALU immediate ---
                3'b001: begin
                    case (op[2:0])
                        3'd0: alu_result = alu_calc(a0, ir_opr, ALU_ADD, flag_c);
                        3'd1: alu_result = alu_calc(a0, ir_opr, ALU_SUB, flag_c);
                        3'd2: alu_result = alu_calc(a0, ir_opr, ALU_SUB, flag_c); // CMPI
                        3'd3: alu_result = alu_calc(a0, ir_opr, ALU_AND, flag_c);
                        3'd4: alu_result = alu_calc(a0, ir_opr, ALU_OR,  flag_c);
                        3'd5: alu_result = alu_calc(a0, ir_opr, ALU_XOR, flag_c);
                        3'd6: alu_result = alu_calc(a0, ir_opr, ALU_AND, flag_c); // TST
                        default: alu_result = 9'd0;
                    endcase
                    if (op[2:0] != 3'd2 && op[2:0] != 3'd6) // not CMP/TST
                        a0 <= alu_result[7:0];
                    flag_z <= (alu_result[7:0] == 8'd0);
                    flag_c <= alu_result[8];
                    flag_n <= alu_result[7];
                end

                // --- Unit 2: Load/Store ---
                3'b010: begin
                    // Compute address
                    case (op[4:3])
                        2'b00: daddr <= {pg, ir_opr};         // pg:imm
                        2'b01: daddr <= {pg, t0};             // pg:t0
                        2'b10: daddr <= {8'h00, ir_opr};      // zp:imm
                        2'b11: daddr <= {8'h01, sp + ir_opr}; // sp+imm
                    endcase
                    if (!op[2]) begin // Load
                        drd <= 1'b1;
                        state <= S_M1;
                    end else begin // Store
                        dout <= a0;
                        dwr <= 1'b1;
                        state <= S_M2;
                    end
                end

                // --- Unit 3: Branch ---
                3'b011: begin
                    case (op[2:0])
                        3'd0: if (flag_z)  pc <= pc + {{8{ir_opr[7]}}, ir_opr};
                        3'd1: if (!flag_z) pc <= pc + {{8{ir_opr[7]}}, ir_opr};
                        3'd2: if (flag_c)  pc <= pc + {{8{ir_opr[7]}}, ir_opr};
                        3'd3: if (!flag_c) pc <= pc + {{8{ir_opr[7]}}, ir_opr};
                        3'd4: if (flag_n)  pc <= pc + {{8{ir_opr[7]}}, ir_opr};
                        3'd5: if (!flag_n) pc <= pc + {{8{ir_opr[7]}}, ir_opr};
                        3'd6: pc <= pc + {{8{ir_opr[7]}}, ir_opr}; // BRA
                        default: ;
                    endcase
                end

                // --- Unit 4: Shift/Unary ---
                3'b100: begin
                    case (op[2:0])
                        3'd0: alu_result = alu_calc(a0, 8'd0, ALU_SHL, flag_c);
                        3'd1: alu_result = alu_calc(a0, 8'd0, ALU_SHR, flag_c);
                        3'd2: alu_result = alu_calc(a0, 8'd0, ALU_ROL, flag_c);
                        3'd3: alu_result = alu_calc(a0, 8'd0, ALU_ROR, flag_c);
                        3'd4: alu_result = alu_calc(a0, 8'd0, ALU_INC, flag_c);
                        3'd5: alu_result = alu_calc(a0, 8'd0, ALU_DEC, flag_c);
                        3'd6: alu_result = alu_calc(a0, 8'd0, ALU_NOT, flag_c);
                        3'd7: alu_result = alu_calc(a0, 8'd0, ALU_SWAP,flag_c);
                    endcase
                    a0 <= alu_result[7:0];
                    flag_z <= (alu_result[7:0] == 8'd0);
                    flag_c <= alu_result[8];
                    flag_n <= alu_result[7];
                end

                // --- Unit 5: Load Immediate + MOV ---
                3'b101: begin
                    if (!op[4]) begin
                        // LI: op[4]=0, op[1:0]=reg select
                        case (op[1:0])
                            2'd0: begin a0 <= ir_opr; flag_z <= (ir_opr == 8'd0); flag_n <= ir_opr[7]; end
                            2'd1: begin t0 <= ir_opr; end
                            2'd2: begin sp <= ir_opr; end
                            2'd3: begin
                                pg <= ir_opr;
                                dout <= ir_opr;
                                dpgwr <= 1'b1;
                            end
                        endcase
                    end else begin
                        // MOV: op[4]=1, op[3:2]=dst, op[1:0]=src
                        // src: 0=a0, 1=t0, 2=sp, 3=pg
                        case (op[3:2])
                            2'd0: begin // dst = a0
                                case (op[1:0])
                                    2'd1: a0 <= t0;
                                    2'd2: a0 <= sp;
                                    2'd3: a0 <= pg;
                                    default: ;
                                endcase
                                flag_z <= (a0 == 8'd0); // will use new value next cycle
                            end
                            2'd1: begin // dst = t0
                                case (op[1:0])
                                    2'd0: t0 <= a0;
                                    2'd2: t0 <= sp;
                                    2'd3: t0 <= pg;
                                    default: ;
                                endcase
                            end
                            2'd2: begin // dst = sp
                                case (op[1:0])
                                    2'd0: sp <= a0;
                                    2'd1: sp <= t0;
                                    2'd3: sp <= pg;
                                    default: ;
                                endcase
                            end
                            2'd3: begin // dst = pg
                                case (op[1:0])
                                    2'd0: begin pg <= a0; dout <= a0; dpgwr <= 1'b1; end
                                    2'd1: begin pg <= t0; dout <= t0; dpgwr <= 1'b1; end
                                    2'd2: begin pg <= sp; dout <= sp; dpgwr <= 1'b1; end
                                    default: ;
                                endcase
                            end
                        endcase
                    end
                end

                // --- Unit 6: Stack/Jump ---
                3'b110: begin
                    case (op[2:0])
                        3'd0: begin // PUSH a0
                            sp <= sp - 8'd1;
                            daddr <= {8'h01, sp - 8'd1};
                            dout <= a0;
                            dwr <= 1'b1;
                            state <= S_M2;
                        end
                        3'd1: begin // PUSH t0
                            sp <= sp - 8'd1;
                            daddr <= {8'h01, sp - 8'd1};
                            dout <= t0;
                            dwr <= 1'b1;
                            state <= S_M2;
                        end
                        3'd2: begin // POP a0
                            daddr <= {8'h01, sp};
                            drd <= 1'b1;
                            sub_state <= 3'd0; // mark: pop to a0
                            state <= S_S2;
                        end
                        3'd3: begin // POP t0
                            daddr <= {8'h01, sp};
                            drd <= 1'b1;
                            sub_state <= 3'd1; // mark: pop to t0
                            state <= S_S2;
                        end
                        3'd4: begin // JAL imm — push PC, jump to {pg, imm}
                            sub_state <= 3'd0;
                            state <= S_S3;
                        end
                        3'd5: begin // RET — pop PCL, pop PCH
                            daddr <= {8'h01, sp};
                            drd <= 1'b1;
                            sub_state <= 3'd3; // go to PCL pop
                            state <= S_S2;
                        end
                        3'd6: begin // JMP pg:imm — direct jump, no push
                            pc <= {pg, ir_opr};
                        end
                        default: ;
                    endcase
                end

                // --- Unit 7: System ---
                3'b111: begin
                    case (op[3:0])
                        4'd0: ; // NOP
                        4'd1: begin // HLT — just stay in F0 but don't advance
                            // Simple: loop back to F0, check interrupts
                            state <= S_F0;
                            pc <= pc - 16'd2; // re-fetch HLT until interrupt
                        end
                        4'd2: flag_ie <= 1'b1; // EI
                        4'd3: flag_ie <= 1'b0; // DI
                        4'd4: flag_c <= 1'b0;  // CLC
                        4'd5: flag_c <= 1'b1;  // SEC
                        4'd6: begin // TRAP
                            state <= S_INT;
                            sub_state <= 3'd0;
                            int_type <= 2'd2;
                            doing_int <= 1'b1;
                        end
                        4'd7: begin // RTI — pop flags, pop PCL, pop PCH
                            daddr <= {8'h01, sp};
                            drd <= 1'b1;
                            sub_state <= 3'd2; // RTI sequence
                            state <= S_S2;
                        end
                        4'd8: skip_flag <= flag_z;   // SKIPZ
                        4'd9: skip_flag <= !flag_z;  // SKIPNZ
                        4'd10: skip_flag <= flag_c;  // SKIPC
                        4'd11: skip_flag <= !flag_c; // SKIPNC
                        default: ;
                    endcase
                end
                endcase
            end
        end

        // ===================== MEMORY READ =====================
        S_M1: begin
            a0 <= data_in;
            flag_z <= (data_in == 8'd0);
            flag_n <= data_in[7];
            state <= S_F0;
        end

        // ===================== MEMORY WRITE =====================
        S_M2: begin
            state <= S_F0;
        end

        // ===================== STACK POP =====================
        S_S2: begin
            case (sub_state)
                3'd0: begin // POP a0
                    a0 <= data_in;
                    sp <= sp + 8'd1;
                    state <= S_F0;
                end
                3'd1: begin // POP t0
                    t0 <= data_in;
                    sp <= sp + 8'd1;
                    state <= S_F0;
                end
                3'd2: begin // RTI: pop flags
                    flag_z <= data_in[0];
                    flag_c <= data_in[1];
                    flag_n <= data_in[2];
                    flag_ie <= data_in[3];
                    sp <= sp + 8'd1;
                    // next: pop PCL
                    daddr <= {8'h01, sp + 8'd1};
                    drd <= 1'b1;
                    sub_state <= 3'd3;
                end
                3'd3: begin // RET/RTI: pop PCL
                    pc[7:0] <= data_in;
                    sp <= sp + 8'd1;
                    // next: pop PCH
                    daddr <= {8'h01, sp + 8'd1};
                    drd <= 1'b1;
                    sub_state <= 3'd4;
                end
                3'd4: begin // RET/RTI: pop PCH
                    pc[15:8] <= data_in;
                    sp <= sp + 8'd1;
                    doing_int <= 1'b0;
                    state <= S_F0;
                end
                default: state <= S_F0;
            endcase
        end

        // ===================== PUSH PCH (JAL/INT) =====================
        S_S3: begin
            sp <= sp - 8'd1;
            daddr <= {8'h01, sp - 8'd1};
            dout <= pc[15:8];
            dwr <= 1'b1;
            state <= S_S4;
        end

        // ===================== PUSH PCL (JAL/INT) =====================
        S_S4: begin
            sp <= sp - 8'd1;
            daddr <= {8'h01, sp - 8'd1};
            dout <= pc[7:0];
            dwr <= 1'b1;
            if (doing_int) begin
                // Push flags next
                state <= S_INT;
                sub_state <= 3'd3;
            end else begin
                // JAL: load new PC
                pc <= {pg, ir_opr};
                state <= S_F0;
            end
        end

        // ===================== INTERRUPT SEQUENCE =====================
        S_INT: begin
            case (sub_state)
                3'd0: begin // Start: push PCH
                    state <= S_S3;
                end
                3'd3: begin // Push flags
                    sp <= sp - 8'd1;
                    daddr <= {8'h01, sp - 8'd1};
                    dout <= {4'b0, flag_ie, flag_n, flag_c, flag_z};
                    dwr <= 1'b1;
                    flag_ie <= 1'b0; // disable interrupts
                    sub_state <= 3'd4;
                end
                3'd4: begin // Load vector: set PC to vector address, read low byte
                    case (int_type)
                        2'd0: pc <= 16'h3FFE; // IRQ
                        2'd1: pc <= 16'h3FFA; // NMI
                        2'd2: pc <= 16'h3FF8; // TRAP
                        default: pc <= 16'h3FFC; // RESET
                    endcase
                    sub_state <= 3'd5;
                end
                3'd5: begin // Read vector low byte from ROM (code_data = rom[pc])
                    vector_addr[7:0] <= code_data;
                    pc <= pc + 16'd1;
                    sub_state <= 3'd6;
                end
                3'd6: begin // Read vector high byte from ROM
                    vector_addr[15:8] <= code_data;
                    // Jump to handler
                    pc <= {code_data, vector_addr[7:0]};
                    doing_int <= 1'b0;
                    nmi_pending <= 1'b0;
                    state <= S_F0;
                end
                default: state <= S_F0;
            endcase
        end

        default: state <= S_F0;
        endcase
    end
end

endmodule
