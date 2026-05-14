// ============================================================
// RV8 CPU — Synthesizable Structural Version (FPGA target)
// Separate modules, clean interfaces, no behavioral tricks
// ============================================================

// --- ALU (combinational) ---
module rv8_alu (
    input  wire [7:0] a, b,
    input  wire [2:0] op,
    input  wire       ci,
    output reg  [7:0] result,
    output reg        co,
    output wire       zero,
    output wire       neg
);
    always @(*) begin
        co = 1'b0;
        case (op)
            3'd0: {co, result} = {1'b0,a} + {1'b0,b};         // ADD
            3'd1: {co, result} = {1'b0,a} - {1'b0,b};         // SUB
            3'd2: result = a & b;                               // AND
            3'd3: result = a | b;                               // OR
            3'd4: result = a ^ b;                               // XOR
            3'd5: begin result = {1'b0, a[7:1]}; co = a[0]; end // SHR
            3'd6: begin result = {a[6:0], 1'b0}; co = a[7]; end // SHL
            3'd7: result = b;                                   // PASS
            default: result = 8'd0;
        endcase
    end
    assign zero = (result == 8'd0);
    assign neg  = result[7];
endmodule

// --- Register (8-bit, synchronous load) ---
module rv8_reg8 (
    input  wire       clk, rst_n, ld,
    input  wire [7:0] d,
    output reg  [7:0] q
);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) q <= 8'd0;
        else if (ld) q <= d;
endmodule

// --- Counter/Register (8-bit, load + increment + decrement) ---
module rv8_cntr8 (
    input  wire       clk, rst_n, ld, inc, dec,
    input  wire [7:0] d,
    output reg  [7:0] q
);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) q <= 8'd0;
        else if (ld)  q <= d;
        else if (inc) q <= q + 8'd1;
        else if (dec) q <= q - 8'd1;
endmodule

// --- Program Counter (16-bit, load + increment + branch) ---
module rv8_pc (
    input  wire        clk, rst_n,
    input  wire        inc, load, branch,
    input  wire [15:0] load_val,
    input  wire [7:0]  offset,
    output reg  [15:0] pc
);
    always @(posedge clk or negedge rst_n)
        if (!rst_n)       pc <= 16'd0;
        else if (load)    pc <= load_val;
        else if (branch)  pc <= pc + {{8{offset[7]}}, offset};
        else if (inc)     pc <= pc + 16'd1;
endmodule

// --- Pointer Pair (16-bit, load_lo + load_hi + inc16 + dec16 + add) ---
module rv8_ptr (
    input  wire        clk, rst_n,
    input  wire        ld_lo, ld_hi, inc, dec,
    input  wire        add_imm,
    input  wire [7:0]  d,
    output wire [15:0] ptr,
    output wire [7:0]  lo, hi
);
    reg [15:0] p;
    assign ptr = p;
    assign lo = p[7:0];
    assign hi = p[15:8];
    always @(posedge clk or negedge rst_n)
        if (!rst_n)      p <= 16'd0;
        else if (ld_lo)  p[7:0]  <= d;
        else if (ld_hi)  p[15:8] <= d;
        else if (inc)    p <= p + 16'd1;
        else if (dec)    p <= p - 16'd1;
        else if (add_imm) p <= p + {8'd0, d};
endmodule

// --- Flags Register ---
module rv8_flags (
    input  wire       clk, rst_n,
    input  wire       ld_alu,      // load from ALU result
    input  wire       ld_byte,     // load from byte (RTI)
    input  wire       set_c, clr_c,
    input  wire       clr_ie, set_ie,
    input  wire       az, ac, an,  // ALU outputs
    input  wire [7:0] byte_in,     // for RTI restore
    output reg        fz, fc, fn, fie
);
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin fz<=0; fc<=0; fn<=0; fie<=0; end
        else begin
            if (ld_alu)  begin fz<=az; fc<=ac; fn<=an; end
            if (ld_byte) begin fz<=byte_in[1]; fc<=byte_in[2]; fn<=byte_in[3]; fie<=byte_in[0]; end
            if (set_c)   fc <= 1'b1;
            if (clr_c)   fc <= 1'b0;
            if (set_ie)  fie <= 1'b1;
            if (clr_ie)  fie <= 1'b0;
        end
endmodule

// --- Constant Generator ---
module rv8_constgen (
    input  wire [1:0] sel,
    output reg  [7:0] val
);
    always @(*)
        case (sel)
            2'd0: val = 8'h00;
            2'd1: val = 8'h01;
            2'd2: val = 8'hFF;
            2'd3: val = 8'h80;
        endcase
endmodule

// --- Address Mux ---
module rv8_addrmux (
    input  wire [2:0]  sel,
    input  wire [15:0] pc, ptr,
    input  wire [7:0]  sp, pg, imm,
    output reg  [15:0] addr
);
    always @(*)
        case (sel)
            3'd0: addr = pc;                    // fetch
            3'd1: addr = ptr;                   // pointer indirect
            3'd2: addr = {8'h30, sp};           // stack
            3'd3: addr = {8'h00, imm};          // zero-page
            3'd4: addr = {pg, imm};             // page-relative
            3'd5: addr = {8'h30, sp + imm};     // stack-relative
            3'd6: addr = {8'hFF, imm};          // vector
            default: addr = pc;
        endcase
endmodule

// --- Top-Level (structural, synthesizable) ---
module rv8_synth (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        nmi_n,
    input  wire        irq_n,
    output wire [15:0] addr,
    input  wire [7:0]  data_in,
    output wire [7:0]  data_out,
    output wire        mem_rd,
    output wire        mem_wr,
    output wire        halt
);
    // Internal buses
    wire [7:0] alu_result, alu_a, alu_b;
    wire       alu_co, alu_z, alu_n;
    wire [7:0] a0_q, t0_q, sp_q, pg_q;
    wire [7:0] pl_q, ph_q;
    wire [15:0] pc_q, ptr_q;
    wire       fz, fc, fn, fie;
    wire [7:0] const_val;

    // Control signals (from control unit)
    wire       a0_ld, t0_ld, sp_ld, pg_ld;
    wire       sp_inc, sp_dec;
    wire       ptr_ld_lo, ptr_ld_hi, ptr_inc, ptr_dec, ptr_add;
    wire       pc_inc, pc_load, pc_branch;
    wire [15:0] pc_load_val;
    wire [7:0]  pc_offset;
    wire [2:0] alu_op;
    wire [2:0] addr_sel;
    wire [7:0] addr_imm;
    wire       flags_ld_alu, flags_ld_byte, flags_set_c, flags_clr_c;
    wire       flags_set_ie, flags_clr_ie;
    wire [1:0] const_sel;
    wire       ir_ld_op, ir_ld_opr;
    wire       mem_rd_out, mem_wr_out;
    wire       halt_out;
    wire [7:0] dout_sel;

    // IR
    reg [7:0] ir_op, ir_opr;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin ir_op <= 8'hFE; ir_opr <= 8'h00; end
        else begin
            if (ir_ld_op)  ir_op  <= data_in;
            if (ir_ld_opr) ir_opr <= data_in;
        end

    // Instances
    rv8_alu ALU (.a(alu_a), .b(alu_b), .op(alu_op), .ci(fc),
                 .result(alu_result), .co(alu_co), .zero(alu_z), .neg(alu_n));

    rv8_reg8 A0 (.clk(clk), .rst_n(rst_n), .ld(a0_ld), .d(alu_result), .q(a0_q));
    rv8_reg8 T0 (.clk(clk), .rst_n(rst_n), .ld(t0_ld), .d(data_in), .q(t0_q));
    rv8_reg8 PG (.clk(clk), .rst_n(rst_n), .ld(pg_ld), .d(data_in), .q(pg_q));

    rv8_cntr8 SP (.clk(clk), .rst_n(rst_n), .ld(sp_ld), .inc(sp_inc), .dec(sp_dec),
                  .d(data_in), .q(sp_q));

    rv8_ptr PTR (.clk(clk), .rst_n(rst_n), .ld_lo(ptr_ld_lo), .ld_hi(ptr_ld_hi),
                 .inc(ptr_inc), .dec(ptr_dec), .add_imm(ptr_add),
                 .d(data_in), .ptr(ptr_q), .lo(pl_q), .hi(ph_q));

    rv8_pc PC (.clk(clk), .rst_n(rst_n), .inc(pc_inc), .load(pc_load),
              .branch(pc_branch), .load_val(pc_load_val), .offset(pc_offset), .pc(pc_q));

    rv8_flags FLAGS (.clk(clk), .rst_n(rst_n),
                     .ld_alu(flags_ld_alu), .ld_byte(flags_ld_byte),
                     .set_c(flags_set_c), .clr_c(flags_clr_c),
                     .set_ie(flags_set_ie), .clr_ie(flags_clr_ie),
                     .az(alu_z), .ac(alu_co), .an(alu_n),
                     .byte_in(data_in),
                     .fz(fz), .fc(fc), .fn(fn), .fie(fie));

    rv8_constgen CGEN (.sel(const_sel), .val(const_val));

    rv8_addrmux AMUX (.sel(addr_sel), .pc(pc_q), .ptr(ptr_q),
                      .sp(sp_q), .pg(pg_q), .imm(addr_imm), .addr(addr));

    // Output assignments
    assign mem_rd   = mem_rd_out;
    assign mem_wr   = mem_wr_out;
    assign halt     = halt_out;
    assign data_out = dout_sel;
    assign alu_a    = a0_q;

    // Note: Control unit (rv8_control) would generate all control signals
    // based on ir_op, ir_opr, flags, and state. Left as exercise or
    // use the behavioral rv8_cpu.v as reference for the state machine.
    //
    // For FPGA synthesis, instantiate a control module here that drives:
    //   a0_ld, t0_ld, sp_ld, pg_ld, sp_inc, sp_dec,
    //   ptr_ld_lo, ptr_ld_hi, ptr_inc, ptr_dec, ptr_add,
    //   pc_inc, pc_load, pc_branch, pc_load_val, pc_offset,
    //   alu_op, addr_sel, addr_imm,
    //   flags_ld_alu, flags_ld_byte, flags_set_c, flags_clr_c,
    //   flags_set_ie, flags_clr_ie,
    //   const_sel, ir_ld_op, ir_ld_opr,
    //   mem_rd_out, mem_wr_out, halt_out, dout_sel

endmodule
