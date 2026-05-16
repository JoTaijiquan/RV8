`timescale 1ns / 1ps
// RV8 CPU — Microcode-driven model
// Models actual hardware: step counter + Flash ROM lookup + control signals
// This is what the real breadboard does.

module rv8_cpu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        irq_n,
    output wire [15:0] addr,
    output wire [7:0]  data_out,
    input  wire [7:0]  data_in,
    output wire        mem_rd,
    output wire        mem_wr
);

// === CONTROL WORD BITS (from microcode ROM) ===
// U23 (low byte):
localparam BUF_OE    = 0;
localparam BUF_DIR   = 1;
localparam PC_ADDR   = 2;
localparam ADDR_CLK  = 3;
localparam PC_INC    = 4;
localparam IR_CLK    = 5;
localparam OPR_CLK   = 6;
localparam STEP_RST  = 7;
// U27 (high byte):
localparam REG_RD_EN = 8;
localparam REG_WR_EN = 9;
localparam ALUB_CLK  = 10;
localparam ALUR_CLK  = 11;
localparam ALU_SUB   = 12;
localparam FLAGS_CLK = 13;
localparam PC_LOAD   = 14;
localparam ADDR_HI   = 15;

// === MICROCODE ROM (16K entries × 16 bits) ===
reg [15:0] ucode [0:16383]; // 14-bit address → 16-bit control word

// === REGISTERS ===
reg [7:0] regs [0:7];  // r0-r7
reg [15:0] pc;
reg [7:0] ir_op, ir_opr;
reg [7:0] alu_b_reg;   // ALU B latch
reg [7:0] alu_r_reg;   // ALU result latch
reg [7:0] addr_lo, addr_hi; // address latches
reg flag_z, flag_c;
reg [2:0] step;         // step counter (0-7)

// === DECODE ===
wire [2:0] rd = ir_op[2:0];
wire [2:0] rs = ir_opr[7:5];

// === MICROCODE ADDRESS ===
wire [13:0] ucode_addr = {irq_n, flag_c, flag_z, step, ir_op};
wire [15:0] ctrl = ucode[ucode_addr];

// === ALU ===
wire [7:0] alu_a = regs[rd]; // rd value (read via IBUS conceptually)
wire [7:0] alu_b = alu_b_reg;
wire [8:0] alu_sum = ctrl[ALU_SUB] ? 
    ({1'b0, alu_a} - {1'b0, alu_b}) : 
    ({1'b0, alu_a} + {1'b0, alu_b});
wire alu_zero = (alu_sum[7:0] == 8'd0);
wire alu_carry = alu_sum[8];

// === ADDRESS BUS ===
assign addr = ctrl[PC_ADDR] ? pc : {addr_hi, addr_lo};

// === DATA BUS ===
assign data_out = regs[rd]; // for store operations
assign mem_rd = ctrl[BUF_OE] & ~ctrl[BUF_DIR]; // read when buffer enabled + dir=read
assign mem_wr = ctrl[BUF_OE] & ctrl[BUF_DIR];  // write when buffer enabled + dir=write

// === MAIN LOGIC ===
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc <= 16'hC000;
        step <= 3'd0;
        ir_op <= 8'd0;
        ir_opr <= 8'd0;
        alu_b_reg <= 8'd0;
        alu_r_reg <= 8'd0;
        addr_lo <= 8'd0;
        addr_hi <= 8'd0;
        flag_z <= 1'b0;
        flag_c <= 1'b0;
        for (i = 0; i < 8; i = i + 1) regs[i] = 8'd0;
    end else begin
        // Step counter
        if (ctrl[STEP_RST])
            step <= 3'd0;
        else
            step <= step + 3'd1;

        // PC increment
        if (ctrl[PC_INC])
            pc <= pc + 16'd1;

        // PC load (branch/jump — PC += signed operand)
        if (ctrl[PC_LOAD])
            pc <= pc + {{8{ir_opr[7]}}, ir_opr};

        // IR latch
        if (ctrl[IR_CLK])
            ir_op <= data_in;

        // Operand latch
        if (ctrl[OPR_CLK])
            ir_opr <= data_in;

        // ALU B latch (from operand or from register via IBUS)
        if (ctrl[ALUB_CLK])
            alu_b_reg <= ctrl[REG_RD_EN] ? regs[rs] : ir_opr;

        // ALU result latch
        if (ctrl[ALUR_CLK])
            alu_r_reg <= alu_sum[7:0];

        // Flags
        if (ctrl[FLAGS_CLK]) begin
            flag_z <= alu_zero;
            flag_c <= alu_carry;
        end

        // Register write (from ALU result)
        if (ctrl[REG_WR_EN] && rd != 3'd0) // never write r0
            regs[rd] <= alu_r_reg;

        // Address latch low
        if (ctrl[ADDR_CLK])
            addr_lo <= data_in; // or from register/ALU

        // Address latch high
        if (ctrl[ADDR_HI])
            addr_hi <= data_in;

        // r0 always zero
        regs[0] <= 8'd0;
    end
end

// === LOAD MICROCODE FROM FILE ===
initial begin
    $readmemh("microcode.hex", ucode);
end

endmodule
