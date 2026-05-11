// ============================================================
// Minimal RISC-V CPU (RV32I subset) - Educational Design
// Single-cycle, easy to understand for middle school students
// ============================================================

// --- Program Counter ---
module pc_reg (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] pc_next,
    output reg  [31:0] pc
);
    always @(posedge clk or posedge rst)
        if (rst) pc <= 32'b0;
        else     pc <= pc_next;
endmodule

// --- Register File: 32 registers, x0 is always zero ---
module reg_file (
    input  wire        clk,
    input  wire        we,       // write enable
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);
    reg [31:0] regs [0:31];
    integer i;

    assign rs1_data = (rs1_addr == 0) ? 32'b0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 0) ? 32'b0 : regs[rs2_addr];

    always @(posedge clk)
        if (we && rd_addr != 0)
            regs[rd_addr] <= rd_data;

    initial for (i = 0; i < 32; i = i + 1) regs[i] = 32'b0;
endmodule

// --- ALU ---
module alu (
    input  wire [3:0]  alu_op,
    input  wire [31:0] a,
    input  wire [31:0] b,
    output reg  [31:0] result,
    output wire        zero
);
    localparam ADD = 4'd0, SUB = 4'd1, AND = 4'd2, OR = 4'd3, SLT = 4'd4;

    always @(*) begin
        case (alu_op)
            ADD:     result = a + b;
            SUB:     result = a - b;
            AND:     result = a & b;
            OR:      result = a | b;
            SLT:     result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: result = 32'b0;
        endcase
    end

    assign zero = (result == 32'b0);
endmodule

// --- Instruction Memory (ROM) ---
module imem (
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] mem [0:63]; // 64 words
    assign instr = mem[addr[7:2]]; // word-aligned
endmodule

// --- Data Memory (RAM) ---
module dmem (
    input  wire        clk,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata
);
    reg [31:0] mem [0:63]; // 64 words
    assign rdata = mem[addr[7:2]];

    always @(posedge clk)
        if (we) mem[addr[7:2]] <= wdata;
endmodule

// --- Immediate Generator ---
module imm_gen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);
    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            7'b0010011, // I-type (ADDI etc)
            7'b0000011: // Load
                imm = {{20{instr[31]}}, instr[31:20]};
            7'b0100011: // S-type (Store)
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            7'b1100011: // B-type (Branch)
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            7'b1101111: // J-type (JAL)
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            7'b0110111: // U-type (LUI)
                imm = {instr[31:12], 12'b0};
            default:
                imm = 32'b0;
        endcase
    end
endmodule

// --- Control Unit ---
module control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_we,
    output reg        mem_we,
    output reg        mem_to_reg,
    output reg        alu_src,    // 0=rs2, 1=imm
    output reg  [3:0] alu_op,
    output reg        branch,
    output reg        jal,
    output reg        lui
);
    always @(*) begin
        // Defaults
        reg_we     = 0; mem_we    = 0; mem_to_reg = 0;
        alu_src    = 0; alu_op    = 4'd0;
        branch     = 0; jal       = 0; lui        = 0;

        case (opcode)
            7'b0110011: begin // R-type: ADD, SUB, AND, OR, SLT
                reg_we = 1;
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? 4'd1 : 4'd0; // SUB : ADD
                    3'b111: alu_op = 4'd2; // AND
                    3'b110: alu_op = 4'd3; // OR
                    3'b010: alu_op = 4'd4; // SLT
                    default: alu_op = 4'd0;
                endcase
            end
            7'b0010011: begin // I-type: ADDI
                reg_we  = 1;
                alu_src = 1;
                alu_op  = 4'd0; // ADD
            end
            7'b0000011: begin // Load: LW
                reg_we     = 1;
                alu_src    = 1;
                mem_to_reg = 1;
                alu_op     = 4'd0;
            end
            7'b0100011: begin // Store: SW
                mem_we  = 1;
                alu_src = 1;
                alu_op  = 4'd0;
            end
            7'b1100011: begin // Branch: BEQ
                branch = 1;
                alu_op = 4'd1; // SUB to compare
            end
            7'b1101111: begin // JAL
                reg_we = 1;
                jal    = 1;
            end
            7'b0110111: begin // LUI
                reg_we = 1;
                lui    = 1;
            end
            default: ;
        endcase
    end
endmodule

// --- Top-Level CPU ---
module riscv_cpu (
    input wire clk,
    input wire rst
);
    // Wires
    wire [31:0] pc, pc_plus4, pc_next, instr;
    wire [31:0] rs1_data, rs2_data, rd_data;
    wire [31:0] imm, alu_a, alu_b, alu_result;
    wire [31:0] mem_rdata;
    wire        alu_zero;

    // Control signals
    wire        reg_we, mem_we, mem_to_reg, alu_src;
    wire [3:0]  alu_op;
    wire        branch, jal, lui;

    // Decode fields
    wire [6:0]  opcode = instr[6:0];
    wire [4:0]  rd     = instr[11:7];
    wire [2:0]  funct3 = instr[14:12];
    wire [4:0]  rs1    = instr[19:15];
    wire [4:0]  rs2    = instr[24:20];
    wire [6:0]  funct7 = instr[31:25];

    // PC logic
    assign pc_plus4 = pc + 32'd4;

    wire        take_branch = branch & alu_zero;
    wire [31:0] branch_target = pc + imm;
    assign pc_next = jal         ? (pc + imm) :
                     take_branch ? branch_target :
                     pc_plus4;

    // ALU inputs
    assign alu_a = rs1_data;
    assign alu_b = alu_src ? imm : rs2_data;

    // Write-back mux
    assign rd_data = lui        ? imm :
                     jal        ? pc_plus4 :
                     mem_to_reg ? mem_rdata :
                     alu_result;

    // Module instances
    pc_reg PC   (.clk(clk), .rst(rst), .pc_next(pc_next), .pc(pc));
    imem   IMEM (.addr(pc), .instr(instr));
    reg_file RF (.clk(clk), .we(reg_we),
                 .rs1_addr(rs1), .rs2_addr(rs2), .rd_addr(rd),
                 .rd_data(rd_data), .rs1_data(rs1_data), .rs2_data(rs2_data));
    imm_gen IG  (.instr(instr), .imm(imm));
    alu     ALU (.alu_op(alu_op), .a(alu_a), .b(alu_b),
                 .result(alu_result), .zero(alu_zero));
    dmem   DMEM (.clk(clk), .we(mem_we),
                 .addr(alu_result), .wdata(rs2_data), .rdata(mem_rdata));
    control CTRL(.opcode(opcode), .funct3(funct3), .funct7(funct7),
                 .reg_we(reg_we), .mem_we(mem_we), .mem_to_reg(mem_to_reg),
                 .alu_src(alu_src), .alu_op(alu_op),
                 .branch(branch), .jal(jal), .lui(lui));
endmodule
