// ============================================================
// RV8 CPU — Verilog Implementation
// 8-bit accumulator CPU, fixed 2-byte instructions
// Fetch/execute overlap, direct-encoded opcodes
// ============================================================

// --- ALU ---
module rv8_alu (
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    input  wire [2:0]  op,
    input  wire        carry_in,
    output reg  [7:0]  result,
    output wire        carry_out,
    output wire        zero,
    output wire        negative
);
    reg [8:0] tmp;
    always @(*) begin
        case (op)
            3'd0: tmp = a + b + carry_in;          // ADD/ADC
            3'd1: tmp = a - b - ~carry_in;         // SUB/SBC
            3'd2: tmp = {1'b0, a & b};             // AND
            3'd3: tmp = {1'b0, a | b};             // OR
            3'd4: tmp = {1'b0, a ^ b};             // XOR
            3'd5: tmp = {a[0], 1'b0, a[7:1]};     // SHR (C=old bit0)
            3'd6: tmp = {a[7], a[6:0], 1'b0};     // SHL (C=old bit7)
            3'd7: tmp = {1'b0, b};                 // PASS_B (for MOV/LI)
            default: tmp = 9'd0;
        endcase
        result = tmp[7:0];
    end
    assign carry_out = tmp[8];
    assign zero = (result == 8'd0);
    assign negative = result[7];
endmodule

// --- Register File ---
module rv8_regfile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire [2:0]  wr_sel,
    input  wire [2:0]  rd_sel,
    input  wire [7:0]  wr_data,
    output reg  [7:0]  rd_data,
    output wire [7:0]  a0_out,
    output wire [7:0]  sp_out,
    output wire [7:0]  pg_out,
    // Constant generator
    input  wire [1:0]  const_sel
);
    reg [7:0] regs [1:6]; // x1=sp, x2=a0, x3=pl, x4=ph, x5=t0, x6=pg
    integer i;

    assign a0_out = regs[2];
    assign sp_out = regs[1];
    assign pg_out = regs[6];

    // Read with constant generator for x0
    always @(*) begin
        if (rd_sel == 3'd0) begin
            case (const_sel)
                2'd0: rd_data = 8'h00;
                2'd1: rd_data = 8'h01;
                2'd2: rd_data = 8'hFF;
                2'd3: rd_data = 8'h80;
            endcase
        end else
            rd_data = regs[rd_sel];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 1; i <= 6; i = i + 1) regs[i] <= 8'd0;
        end else if (we && wr_sel != 3'd0)
            regs[wr_sel] <= wr_data;
    end
endmodule

// --- Program Counter ---
module rv8_pc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        inc,
    input  wire        load,
    input  wire        branch,
    input  wire [15:0] load_val,
    input  wire [7:0]  offset,
    output reg  [15:0] pc
);
    wire [15:0] branch_target = pc + {{8{offset[7]}}, offset};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 16'hFFFC; // Will load reset vector
        else if (load)
            pc <= load_val;
        else if (branch)
            pc <= branch_target;
        else if (inc)
            pc <= pc + 16'd1;
    end
endmodule

// --- Pointer Register (with auto-increment) ---
module rv8_pointer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        load_pl,
    input  wire        load_ph,
    input  wire        inc16,
    input  wire        dec16,
    input  wire [7:0]  data_in,
    output wire [15:0] ptr_out,
    output wire [7:0]  pl_out,
    output wire [7:0]  ph_out
);
    reg [7:0] pl, ph;
    assign ptr_out = {ph, pl};
    assign pl_out = pl;
    assign ph_out = ph;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pl <= 8'd0; ph <= 8'd0;
        end else if (load_pl)
            pl <= data_in;
        else if (load_ph)
            ph <= data_in;
        else if (inc16)
            {ph, pl} <= {ph, pl} + 16'd1;
        else if (dec16)
            {ph, pl} <= {ph, pl} - 16'd1;
    end
endmodule

// --- Control Unit ---
module rv8_control (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  opcode,
    input  wire [7:0]  operand,
    input  wire        flag_z,
    input  wire        flag_c,
    input  wire        flag_n,
    input  wire        flag_ie,
    input  wire        nmi_pending,
    input  wire        irq_pending,
    // Outputs
    output reg         reg_we,
    output reg         mem_rd,
    output reg         mem_wr,
    output reg  [2:0]  alu_op,
    output reg  [2:0]  addr_src,
    output reg         pc_inc,
    output reg         pc_load,
    output reg         pc_branch,
    output reg         flags_we,
    output reg         ptr_inc,
    output reg         ptr_dec,
    output reg         sp_inc,
    output reg         sp_dec,
    output reg         ir_load0,
    output reg         ir_load1,
    output reg         halt_out,
    output reg         ie_set,
    output reg         ie_clr,
    output reg         skip_set,
    output reg         int_enter,
    output wire [2:0]  state_out
);
    // State machine
    reg [2:0] state, next_state;
    localparam S0 = 3'd0, S1 = 3'd1, S2 = 3'd2, S3 = 3'd3, S4 = 3'd4;
    assign state_out = state;

    // Skip flag
    reg skip_flag;
    wire skip_active = skip_flag;

    // Instruction decode (direct from opcode bits)
    wire [2:0] unit = opcode[7:5];
    wire [2:0] op   = opcode[4:2];
    wire [1:0] reg_field = opcode[1:0];

    // Unit enables
    wire is_alu    = (unit == 3'd0);
    wire is_imm    = (unit == 3'd1);
    wire is_ldst   = (unit == 3'd2);
    wire is_branch = (unit == 3'd3);
    wire is_shift  = (unit == 3'd4);
    wire is_ptr    = (unit == 3'd5);
    wire is_system = (unit == 3'd7);

    // Branch condition check
    reg branch_taken;
    always @(*) begin
        case (op[2:0])
            3'd0: branch_taken = flag_z;          // BEQ
            3'd1: branch_taken = ~flag_z;         // BNE
            3'd2: branch_taken = flag_c;          // BCS
            3'd3: branch_taken = ~flag_c;         // BCC
            3'd4: branch_taken = flag_n;          // BMI
            3'd5: branch_taken = ~flag_n;         // BPL
            3'd6: branch_taken = 1'b1;            // BRA
            3'd7: branch_taken = 1'b0;            // (skip group)
            default: branch_taken = 1'b0;
        endcase
    end

    // Skip condition
    wire is_skip = is_branch && (op[2:1] == 2'b11); // opcodes 0x37-0x3A
    wire skip_cond = (opcode[1:0] == 2'd0) ? flag_z :
                     (opcode[1:0] == 2'd1) ? ~flag_z :
                     (opcode[1:0] == 2'd2) ? flag_c : ~flag_c;

    // Needs S2 (memory access)
    wire needs_s2 = is_ldst && (op >= 3'd0 && op <= 3'd5); // LB/SB variants
    wire is_push  = (opcode == 8'h2C);
    wire is_pop   = (opcode == 8'h2D);
    wire is_jal   = (opcode == 8'h3D);
    wire is_ret   = (opcode == 8'h3E);
    wire is_jmp   = (opcode == 8'h3C);

    // Interrupt check
    wire int_request = ((nmi_pending) || (irq_pending && flag_ie)) && !skip_flag;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
            skip_flag <= 1'b0;
        end else begin
            state <= next_state;
            if (skip_set && !skip_active)
                skip_flag <= 1'b1;
            else if (state == S1 && skip_flag)
                skip_flag <= 1'b0; // Clear after one instruction skipped
            if (int_enter)
                skip_flag <= 1'b0;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = S0;
        case (state)
            S0: next_state = S1;
            S1: begin
                if (int_request && !needs_s2 && !is_push && !is_pop && !is_jal && !is_ret)
                    next_state = S2; // interrupt entry
                else if (needs_s2 || is_push || is_pop)
                    next_state = S2;
                else if (is_jal)
                    next_state = S2;
                else if (is_ret)
                    next_state = S2;
                else
                    next_state = S0; // 2-cycle instruction done
            end
            S2: begin
                if (is_jal) next_state = S3;
                else if (is_ret) next_state = S3;
                else next_state = S0;
            end
            S3: begin
                if (is_jal) next_state = S4;
                else next_state = S0; // RET done
            end
            S4: next_state = S0; // JAL done
            default: next_state = S0;
        endcase
    end

    // Control signal generation
    always @(*) begin
        // Defaults
        reg_we = 0; mem_rd = 0; mem_wr = 0;
        alu_op = 3'd7; addr_src = 3'd0;
        pc_inc = 0; pc_load = 0; pc_branch = 0;
        flags_we = 0; ptr_inc = 0; ptr_dec = 0;
        sp_inc = 0; sp_dec = 0;
        ir_load0 = 0; ir_load1 = 0;
        halt_out = 0; ie_set = 0; ie_clr = 0;
        skip_set = 0; int_enter = 0;

        case (state)
            S0: begin
                addr_src = 3'd0; // PC
                mem_rd = 1;
                ir_load0 = 1;
                pc_inc = 1;
            end

            S1: begin
                addr_src = 3'd0; // PC
                mem_rd = 1;
                ir_load1 = 1;
                pc_inc = 1;

                // Execute previous instruction (if not skipped)
                if (!skip_active) begin
                    if (is_alu) begin
                        alu_op = op;
                        reg_we = (op != 3'd5); // CMP doesn't write (op==5 is CMP? check encoding)
                        flags_we = 1;
                    end
                    else if (is_imm) begin
                        if (op <= 3'd5) begin // LI rd, imm
                            alu_op = 3'd7; // PASS_B
                            reg_we = 1;
                        end else begin // ADDI, SUBI, CMPI, ANDI, ORI, XORI, TST
                            alu_op = op - 3'd6; // map to ALU ops
                            reg_we = (opcode != 8'h18 && opcode != 8'h1C); // CMPI/TST don't write
                            flags_we = 1;
                        end
                    end
                    else if (is_shift) begin
                        flags_we = 1;
                        reg_we = 1;
                    end
                    else if (is_branch && !is_skip) begin
                        if (branch_taken)
                            pc_branch = 1;
                    end
                    else if (is_skip) begin
                        if (skip_cond)
                            skip_set = 1;
                    end
                    else if (is_jmp) begin
                        pc_load = 1;
                    end
                    else if (is_ptr) begin
                        if (op == 3'd0) ptr_inc = 1;
                        else if (op == 3'd1) ptr_dec = 1;
                        // ADD16: handled via ptr_inc repeated (simplified)
                    end
                    else if (is_system) begin
                        case (opcode)
                            8'hF0: ; // CLC — handled in flags
                            8'hF1: ; // SEC — handled in flags
                            8'hF2: ie_set = 1;
                            8'hF3: ie_clr = 1;
                            8'hFF: halt_out = 1;
                        endcase
                    end
                end
            end

            S2: begin
                if (is_ldst && !skip_active) begin
                    // Address source based on sub-opcode
                    case (op)
                        3'd0, 3'd1: addr_src = 3'd1; // ptr
                        3'd2, 3'd3: begin addr_src = 3'd1; ptr_inc = 1; end // ptr+
                        3'd4, 3'd5: addr_src = 3'd2; // stack-relative / zp / pg
                    endcase
                    if (op[0] == 0) begin mem_rd = 1; reg_we = 1; end // LB
                    else begin mem_wr = 1; end // SB
                end
                else if (is_push && !skip_active) begin
                    addr_src = 3'd2; // stack
                    sp_dec = 1;
                    mem_wr = 1;
                end
                else if (is_pop && !skip_active) begin
                    addr_src = 3'd2; // stack
                    mem_rd = 1;
                    reg_we = 1;
                    sp_inc = 1;
                end
                else if (is_jal) begin
                    addr_src = 3'd2; // stack
                    sp_dec = 1;
                    mem_wr = 1; // push PCH
                end
                else if (is_ret) begin
                    addr_src = 3'd2; // stack
                    mem_rd = 1; // pop PCL
                    sp_inc = 1;
                end
            end

            S3: begin
                if (is_jal) begin
                    addr_src = 3'd2;
                    sp_dec = 1;
                    mem_wr = 1; // push PCL
                end
                else if (is_ret) begin
                    addr_src = 3'd2;
                    mem_rd = 1; // pop PCH
                    sp_inc = 1;
                end
            end

            S4: begin
                if (is_jal) begin
                    pc_load = 1; // PC = {ph, pl}
                end
            end
        endcase
    end
endmodule

// --- Top-Level CPU ---
module rv8_cpu (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        nmi_n,
    input  wire        irq_n,
    output wire [15:0] addr_bus,
    inout  wire [7:0]  data_bus,
    output wire        mem_rd_n,
    output wire        mem_wr_n,
    output wire        halt
);
    // Internal wires
    wire [15:0] pc_out;
    wire [15:0] ptr_out;
    wire [7:0]  pl_out, ph_out;
    wire [7:0]  a0_out, sp_out, pg_out;
    wire [7:0]  reg_rd_data;
    wire [7:0]  alu_result, alu_a, alu_b;
    wire        alu_cout, alu_zero, alu_neg;
    wire [2:0]  state;

    // IR
    reg [7:0] ir_opcode, ir_operand;

    // Flags
    reg flag_z, flag_c, flag_n, flag_ie;
    reg nmi_pending;

    // Control signals
    wire reg_we, mem_rd, mem_wr;
    wire [2:0] alu_op, addr_src;
    wire pc_inc, pc_load, pc_branch;
    wire flags_we, ptr_inc, ptr_dec;
    wire sp_inc, sp_dec;
    wire ir_load0, ir_load1;
    wire halt_out, ie_set, ie_clr;
    wire skip_set, int_enter;

    // Data bus control
    wire [7:0] data_out;
    wire data_oe = mem_wr;
    assign data_bus = data_oe ? data_out : 8'bz;
    wire [7:0] data_in = data_bus;

    // Address mux
    reg [15:0] addr_mux;
    always @(*) begin
        case (addr_src)
            3'd0: addr_mux = pc_out;
            3'd1: addr_mux = ptr_out;
            3'd2: addr_mux = {8'h30, sp_out};
            3'd3: addr_mux = {8'h00, ir_operand};  // zero-page
            3'd4: addr_mux = {pg_out, ir_operand};  // page-relative
            3'd5: addr_mux = {8'hFF, ir_operand};   // vector
            default: addr_mux = pc_out;
        endcase
    end
    assign addr_bus = addr_mux;
    assign mem_rd_n = ~mem_rd;
    assign mem_wr_n = ~mem_wr;
    assign halt = halt_out;

    // ALU connections
    assign alu_a = a0_out;
    assign alu_b = reg_rd_data; // or ir_operand for immediate ops
    assign data_out = a0_out; // for store operations

    // IR latching
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ir_opcode <= 8'hFE; // NOP
            ir_operand <= 8'h00;
        end else begin
            if (ir_load0) ir_opcode <= data_in;
            if (ir_load1) ir_operand <= data_in;
        end
    end

    // Flags
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flag_z <= 0; flag_c <= 0; flag_n <= 0; flag_ie <= 0;
        end else begin
            if (flags_we) begin
                flag_z <= alu_zero;
                flag_c <= alu_cout;
                flag_n <= alu_neg;
            end
            if (ie_set) flag_ie <= 1;
            if (ie_clr) flag_ie <= 0;
            if (ir_opcode == 8'hF0) flag_c <= 0; // CLC
            if (ir_opcode == 8'hF1) flag_c <= 1; // SEC
        end
    end

    // NMI edge detect
    reg nmi_prev;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nmi_pending <= 0; nmi_prev <= 1;
        end else begin
            nmi_prev <= nmi_n;
            if (nmi_prev && !nmi_n) nmi_pending <= 1; // falling edge
            if (int_enter) nmi_pending <= 0;
        end
    end

    // Module instances
    rv8_pc PC (
        .clk(clk), .rst_n(rst_n),
        .inc(pc_inc), .load(pc_load), .branch(pc_branch),
        .load_val(ptr_out), .offset(ir_operand),
        .pc(pc_out)
    );

    rv8_pointer PTR (
        .clk(clk), .rst_n(rst_n),
        .load_pl(reg_we && (ir_opcode[2:0] == 3'd3)), // simplified
        .load_ph(reg_we && (ir_opcode[2:0] == 3'd4)),
        .inc16(ptr_inc), .dec16(ptr_dec),
        .data_in(alu_result),
        .ptr_out(ptr_out), .pl_out(pl_out), .ph_out(ph_out)
    );

    rv8_regfile REGS (
        .clk(clk), .rst_n(rst_n),
        .we(reg_we), .wr_sel(3'd2), // default write to a0
        .rd_sel(ir_operand[2:0]),
        .wr_data(alu_result),
        .rd_data(reg_rd_data),
        .a0_out(a0_out), .sp_out(sp_out), .pg_out(pg_out),
        .const_sel(ir_operand[3:2])
    );

    rv8_alu ALU (
        .a(alu_a), .b(alu_b), .op(alu_op),
        .carry_in(flag_c),
        .result(alu_result),
        .carry_out(alu_cout), .zero(alu_zero), .negative(alu_neg)
    );

    rv8_control CTRL (
        .clk(clk), .rst_n(rst_n),
        .opcode(ir_opcode), .operand(ir_operand),
        .flag_z(flag_z), .flag_c(flag_c), .flag_n(flag_n), .flag_ie(flag_ie),
        .nmi_pending(nmi_pending), .irq_pending(~irq_n),
        .reg_we(reg_we), .mem_rd(mem_rd), .mem_wr(mem_wr),
        .alu_op(alu_op), .addr_src(addr_src),
        .pc_inc(pc_inc), .pc_load(pc_load), .pc_branch(pc_branch),
        .flags_we(flags_we), .ptr_inc(ptr_inc), .ptr_dec(ptr_dec),
        .sp_inc(sp_inc), .sp_dec(sp_dec),
        .ir_load0(ir_load0), .ir_load1(ir_load1),
        .halt_out(halt_out), .ie_set(ie_set), .ie_clr(ie_clr),
        .skip_set(skip_set), .int_enter(int_enter),
        .state_out(state)
    );
endmodule
