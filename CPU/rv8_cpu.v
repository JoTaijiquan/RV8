// ============================================================
// RV8 CPU — Minimal 8-bit CPU, Accumulator-based, RISC-inspired
// Fixed 2-byte instructions, direct-encoded opcodes
// Fetch/execute overlap
// ============================================================

// --- ALU ---
module rv8_alu (
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    input  wire [3:0]  op,
    input  wire        carry_in,
    output reg  [7:0]  result,
    output wire        carry_out,
    output wire        zero,
    output wire        negative
);
    reg [8:0] tmp;
    wire borrow = ~carry_in;
    always @(*) begin
        case (op)
            4'd0: tmp = a + b + carry_in;          // ADD/ADC
            4'd1: tmp = a - b - borrow;            // SUB/SBC
            4'd2: tmp = {1'b0, a & b};             // AND
            4'd3: tmp = {1'b0, a | b};             // OR
            4'd4: tmp = {1'b0, a ^ b};             // XOR
            4'd5: tmp = {a[0], 1'b0, a[7:1]};     // SHR (C=old bit0)
            4'd6: tmp = {a[7], a[6:0], 1'b0};     // SHL (C=old bit7)
            4'd7: tmp = {1'b0, b};                 // PASS_B (for MOV/LI)
            4'd8: tmp = {a[7], a[6:0], carry_in};  // ROL (C=old bit7, shift in old C)
            4'd9: tmp = {a[0], carry_in, a[7:1]};  // ROR (C=old bit0, shift in old C)
            4'd10: tmp = a + 9'd1;                  // INC (ignore carry_in)
            4'd11: tmp = a - 9'd1;                  // DEC (ignore carry_in)
            4'd12: tmp = {1'b0, ~a};                // NOT
            4'd13: tmp = {1'b0, a[3:0], a[7:4]};   // SWAP nibbles
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
    input  wire        sp_inc,
    input  wire        sp_dec,
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
        end else begin
            if (we && wr_sel != 3'd0)
                regs[wr_sel] <= wr_data;
            if (sp_inc) regs[1] <= regs[1] + 8'd1;
            if (sp_dec) regs[1] <= regs[1] - 8'd1;
        end
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
    wire [15:0] branch_target = pc + 16'd1 + {{8{offset[7]}}, offset};

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
    input  wire        add_imm,
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
        else if (add_imm)
            {ph, pl} <= {ph, pl} + {8'd0, data_in};
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
    output reg  [3:0]  alu_op,
    output reg  [2:0]  addr_src,
    output reg  [2:0]  wr_sel,
    output reg  [1:0]  alu_b_sel,  // 0=reg_rd_data, 1=ir_operand, 2=zero
    output reg         pc_inc,
    output reg         pc_load,
    output reg         pc_branch,
    output reg         flags_we,
    output reg         ptr_inc,
    output reg         ptr_dec,
    output reg         ptr_add,
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
    localparam S5 = 3'd5, S6 = 3'd6; // Reset vector fetch
    assign state_out = state;

    // Skip flag
    reg skip_flag;
    wire skip_active = skip_flag;

    // Reset tracking
    reg reset_done;

    // Instruction decode (direct from opcode bits)
    wire [2:0] unit = opcode[7:5];
    wire [2:0] op   = opcode[4:2];
    wire [1:0] reg_field = opcode[1:0];

    // Unit enables — based on actual opcode ranges
    wire is_alu    = (opcode[7:3] == 5'b00000);           // 0x00-0x07
    wire is_li     = (opcode >= 8'h10 && opcode <= 8'h15); // 0x10-0x15
    wire is_imm    = (opcode >= 8'h16 && opcode <= 8'h1C); // 0x16-0x1C
    wire is_ldst   = (opcode >= 8'h20 && opcode <= 8'h2B); // 0x20-0x2B
    wire is_branch = (opcode >= 8'h30 && opcode <= 8'h36); // 0x30-0x36
    wire is_skip_grp = (opcode >= 8'h37 && opcode <= 8'h3A);
    wire is_shift  = (opcode >= 8'h40 && opcode <= 8'h47); // 0x40-0x47
    wire is_ptr    = (opcode >= 8'h48 && opcode <= 8'h4A); // 0x48-0x4A
    wire is_system = (opcode[7:4] == 4'hF);                // 0xF0-0xFF

    // Branch condition check
    reg branch_taken;
    always @(*) begin
        case (opcode[2:0])
            3'd0: branch_taken = flag_z;          // BEQ
            3'd1: branch_taken = ~flag_z;         // BNE
            3'd2: branch_taken = flag_c;          // BCS
            3'd3: branch_taken = ~flag_c;         // BCC
            3'd4: branch_taken = flag_n;          // BMI
            3'd5: branch_taken = ~flag_n;         // BPL
            3'd6: branch_taken = 1'b1;            // BRA
            3'd7: branch_taken = 1'b0;
            default: branch_taken = 1'b0;
        endcase
    end

    // Skip condition — opcode[2:0]: 7=SKIPZ, 0=SKIPNZ(0x38), 1=SKIPC(0x39), 2=SKIPNC(0x3A)
    wire is_skip = is_skip_grp;
    wire skip_cond = (opcode == 8'h37) ? flag_z :
                     (opcode == 8'h38) ? ~flag_z :
                     (opcode == 8'h39) ? flag_c : ~flag_c;

    // Needs S2 (memory access)
    wire is_mov   = (opcode == 8'h24 || opcode == 8'h25);
    wire is_push  = (opcode == 8'h2C);
    wire is_pop   = (opcode == 8'h2D);
    wire needs_s2 = (is_ldst && !is_mov) || is_push || is_pop;
    wire is_jal   = (opcode == 8'h3D);
    wire is_ret   = (opcode == 8'h3E);
    wire is_jmp   = (opcode == 8'h3C);

    // Interrupt check
    wire int_request = ((nmi_pending) || (irq_pending && flag_ie)) && !skip_flag;

    // State machine
    // Instruction type for multi-cycle ops (latched at S1)
    reg [2:0] instr_type;
    localparam IT_NONE=0, IT_JAL=1, IT_RET=2, IT_RTI=3, IT_TRAP=4, IT_LDST=5, IT_PUSH=6, IT_POP=7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S5;
            skip_flag <= 1'b0;
            reset_done <= 1'b0;
            instr_type <= IT_NONE;
        end else begin
            state <= next_state;
            if (state == S6) reset_done <= 1'b1;
            if (state == S1) begin
                if (is_jal) instr_type <= IT_JAL;
                else if (is_ret) instr_type <= IT_RET;
                else if (opcode == 8'hF4) instr_type <= IT_RTI;
                else if (opcode == 8'hF5) instr_type <= IT_TRAP;
                else if (is_push) instr_type <= IT_PUSH;
                else if (is_pop) instr_type <= IT_POP;
                else if (is_ldst && !is_mov) instr_type <= IT_LDST;
                else instr_type <= IT_NONE;
            end
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
            S5: next_state = S6;  // Reset: read vector low byte
            S6: next_state = S0;  // Reset: read vector high byte, load PC
            S0: next_state = S1;
            S1: begin
                if (int_request && !needs_s2 && !is_push && !is_pop && !is_jal && !is_ret && opcode != 8'hF4)
                    next_state = S5; // interrupt: go to vector fetch
                else if (needs_s2 || is_push || is_pop)
                    next_state = S2;
                else if (is_jal)
                    next_state = S2;
                else if (is_ret)
                    next_state = S2;
                else if (opcode == 8'hF5) // TRAP
                    next_state = S2;
                else if (opcode == 8'hF4) // RTI
                    next_state = S2;
                else
                    next_state = S0; // 2-cycle instruction done
            end
            S2: begin
                if (instr_type == IT_JAL || instr_type == IT_RET || 
                    instr_type == IT_TRAP || instr_type == IT_RTI)
                    next_state = S3;
                else
                    next_state = S0;
            end
            S3: begin
                if (instr_type == IT_JAL || instr_type == IT_TRAP || instr_type == IT_RTI)
                    next_state = S4;
                else
                    next_state = S0; // RET done
            end
            S4: begin
                if (instr_type == IT_TRAP) next_state = S5; // vector fetch
                else next_state = S0; // JAL/RTI done
            end
            default: next_state = S0;
        endcase
    end

    // Control signal generation
    always @(*) begin
        // Defaults
        reg_we = 0; mem_rd = 0; mem_wr = 0;
        alu_op = 4'd7; addr_src = 3'd0;
        wr_sel = 3'd2; alu_b_sel = 0;
        pc_inc = 0; pc_load = 0; pc_branch = 0;
        flags_we = 0; ptr_inc = 0; ptr_dec = 0; ptr_add = 0;
        sp_inc = 0; sp_dec = 0;
        ir_load0 = 0; ir_load1 = 0;
        halt_out = 0; ie_set = 0; ie_clr = 0;
        skip_set = 0; int_enter = 0;

        case (state)
            S5: begin
                // Vector fetch: read low byte from vector_addr
                mem_rd = 1;
                ir_load0 = 1; // store low byte in ir_opcode temporarily
            end

            S6: begin
                // Vector fetch: read high byte, load PC with vector
                mem_rd = 1;
                pc_load = 1; // PC = {data_in, ir_opcode}
            end

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
                        alu_b_sel = 0; // reg_rd_data
                        wr_sel = 3'd2; // a0
                        flags_we = 1;
                        case (opcode[2:0])
                            3'd0: begin alu_op = 4'd0; reg_we = 1; end // ADD
                            3'd1: begin alu_op = 4'd1; reg_we = 1; end // SUB
                            3'd2: begin alu_op = 4'd2; reg_we = 1; end // AND
                            3'd3: begin alu_op = 4'd3; reg_we = 1; end // OR
                            3'd4: begin alu_op = 4'd4; reg_we = 1; end // XOR
                            3'd5: begin alu_op = 4'd1; reg_we = 0; end // CMP (SUB no write)
                            3'd6: begin alu_op = 4'd0; reg_we = 1; end // ADC
                            3'd7: begin alu_op = 4'd1; reg_we = 1; end // SBC
                            default: begin alu_op = 4'd0; reg_we = 0; end
                        endcase
                    end
                    else if (is_li) begin
                        alu_op = 4'd7; // PASS_B
                        alu_b_sel = 1; // ir_operand
                        wr_sel = opcode[2:0] + 3'd1;
                        reg_we = 1;
                    end
                    else if (is_imm) begin
                        alu_b_sel = 1; // ir_operand
                        wr_sel = 3'd2; // a0
                        case (opcode)
                            8'h16: alu_op = 4'd0; // ADDI
                            8'h17: alu_op = 4'd1; // SUBI
                            8'h18: alu_op = 4'd1; // CMPI
                            8'h19: alu_op = 4'd2; // ANDI
                            8'h1A: alu_op = 4'd3; // ORI
                            8'h1B: alu_op = 4'd4; // XORI
                            8'h1C: alu_op = 4'd2; // TST
                            default: alu_op = 4'd0;
                        endcase
                        reg_we = (opcode != 8'h18 && opcode != 8'h1C);
                        flags_we = 1;
                    end
                    else if (is_shift) begin
                        flags_we = 1;
                        reg_we = 1;
                        wr_sel = 3'd2; // a0
                        case (opcode)
                            8'h40: alu_op = 4'd6;  // SHL
                            8'h41: alu_op = 4'd5;  // SHR
                            8'h42: alu_op = 4'd8;  // ROL
                            8'h43: alu_op = 4'd9;  // ROR
                            8'h44: alu_op = 4'd10; // INC
                            8'h45: alu_op = 4'd11; // DEC
                            8'h46: alu_op = 4'd12; // NOT
                            8'h47: alu_op = 4'd13; // SWAP
                            default: alu_op = 4'd0;
                        endcase
                    end
                    else if (is_mov) begin
                        reg_we = 1;
                        if (opcode == 8'h24) begin
                            // MOV rd, a0: write a0 to dest reg
                            wr_sel = operand[2:0];
                            alu_op = 4'd3; // OR
                            alu_b_sel = 2; // force zero → a0 | 0 = a0
                        end else begin
                            // MOV a0, rs: read rs, pass to a0
                            wr_sel = 3'd2; // a0
                            alu_op = 4'd7; // PASS_B
                            alu_b_sel = 0; // reg_rd_data
                        end
                    end
                    else if (is_branch) begin
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
                        case (opcode)
                            8'h48: ptr_inc = 1;  // INC16
                            8'h49: ptr_dec = 1;  // DEC16
                            8'h4A: ptr_add = 1;  // ADD16 imm
                            default: ;
                        endcase
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

                // Interrupt entry
                if (int_request && !needs_s2 && !is_push && !is_pop && !is_jal && !is_ret) begin
                    int_enter = 1;
                    ie_clr = 1;
                end
            end

            S2: begin
                case (instr_type)
                    IT_LDST: if (!skip_active) begin
                        case (opcode)
                            8'h20: begin addr_src = 3'd1; mem_rd = 1; reg_we = 1; wr_sel = 3'd2; end
                            8'h21: begin addr_src = 3'd1; mem_wr = 1; end
                            8'h22: begin addr_src = 3'd1; mem_rd = 1; reg_we = 1; wr_sel = 3'd2; ptr_inc = 1; end
                            8'h23: begin addr_src = 3'd1; mem_wr = 1; ptr_inc = 1; end
                            8'h26: begin addr_src = 3'd6; mem_rd = 1; reg_we = 1; wr_sel = 3'd2; end
                            8'h27: begin addr_src = 3'd6; mem_wr = 1; end
                            8'h28: begin addr_src = 3'd3; mem_rd = 1; reg_we = 1; wr_sel = 3'd2; end
                            8'h29: begin addr_src = 3'd3; mem_wr = 1; end
                            8'h2A: begin addr_src = 3'd4; mem_rd = 1; reg_we = 1; wr_sel = 3'd2; end
                            8'h2B: begin addr_src = 3'd4; mem_wr = 1; end
                            default: ;
                        endcase
                    end
                    IT_PUSH: if (!skip_active) begin
                        addr_src = 3'd7; sp_dec = 1; mem_wr = 1;
                    end
                    IT_POP: if (!skip_active) begin
                        addr_src = 3'd2; mem_rd = 1; reg_we = 1;
                        wr_sel = operand[2:0]; sp_inc = 1;
                    end
                    IT_JAL: begin
                        addr_src = 3'd7; sp_dec = 1; mem_wr = 1; // push PCH
                    end
                    IT_TRAP: begin
                        addr_src = 3'd7; sp_dec = 1; mem_wr = 1; // push PCH
                    end
                    IT_RET: begin
                        addr_src = 3'd2; mem_rd = 1; sp_inc = 1;
                        ir_load0 = 1; // store PCL in ir_opcode
                    end
                    IT_RTI: begin
                        addr_src = 3'd2; mem_rd = 1; sp_inc = 1; // pop flags
                    end
                    default: ;
                endcase
            end

            S3: begin
                case (instr_type)
                    IT_JAL: begin
                        addr_src = 3'd7; sp_dec = 1; mem_wr = 1; // push PCL
                    end
                    IT_TRAP: begin
                        addr_src = 3'd7; sp_dec = 1; mem_wr = 1; // push PCL
                    end
                    IT_RET: begin
                        addr_src = 3'd2; mem_rd = 1; sp_inc = 1;
                        pc_load = 1; // PC = {data_in(PCH), ir_opcode(PCL)}
                    end
                    IT_RTI: begin
                        addr_src = 3'd2; mem_rd = 1; sp_inc = 1;
                        ir_load0 = 1; // store PCL in ir_opcode
                    end
                    default: ;
                endcase
            end

            S4: begin
                case (instr_type)
                    IT_JAL: begin
                        pc_load = 1; // PC = ptr_out
                    end
                    IT_TRAP: begin
                        addr_src = 3'd7; sp_dec = 1; mem_wr = 1; // push flags
                        ie_clr = 1;
                    end
                    IT_RTI: begin
                        addr_src = 3'd2; mem_rd = 1; sp_inc = 1;
                        pc_load = 1; // PC = {data_in(PCH), ir_opcode(PCL)}
                    end
                    default: ;
                endcase
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
    output wire        halt,
    output wire        sync
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

    // Testbench-visible aliases
    wire [7:0] a0 = a0_out;
    wire [7:0] t0 = REGS.regs[5];
    wire [7:0] sp = sp_out;
    wire [7:0] pl = pl_out;
    wire [7:0] ph = ph_out;
    wire [7:0] pg = pg_out;
    wire fz = flag_z, fc = flag_c, fn = flag_n, fie = flag_ie;

    // Vector address for reset/interrupt fetch
    reg [15:0] vector_addr;

    // IR
    reg [7:0] ir_opcode, ir_operand;

    // Flags
    reg flag_z, flag_c, flag_n, flag_ie;
    reg nmi_pending;

    // Control signals
    wire reg_we, mem_rd, mem_wr;
    wire [3:0] alu_op;
    wire [2:0] addr_src, wr_sel;
    wire [1:0] alu_b_sel_w;
    wire pc_inc, pc_load, pc_branch;
    wire flags_we, ptr_inc, ptr_dec, ptr_add;
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
        if (state == 3'd5)
            addr_mux = vector_addr;
        else if (state == 3'd6)
            addr_mux = vector_addr + 16'd1;
        else begin
            case (addr_src)
                3'd0: addr_mux = pc_out;
                3'd1: addr_mux = ptr_out;
                3'd2: addr_mux = {8'h30, sp_out};           // stack (POP)
                3'd3: addr_mux = {8'h00, ir_operand};       // zero-page
                3'd4: addr_mux = {pg_out, ir_operand};      // page-relative
                3'd5: addr_mux = {8'hFF, ir_operand};       // vector
                3'd6: addr_mux = {8'h30, sp_out + ir_operand}; // sp+imm
                3'd7: addr_mux = {8'h30, sp_out - 8'd1};   // stack pre-dec (PUSH)
                default: addr_mux = pc_out;
            endcase
        end
    end
    assign addr_bus = addr_mux;
    assign mem_rd_n = ~mem_rd;
    assign mem_wr_n = ~mem_wr;
    assign halt = halt_out;
    assign sync = (state == 3'd0);

    // ALU connections
    assign alu_a = a0_out;
    assign alu_b = (alu_b_sel_w == 2'd2) ? 8'd0 :
                   (alu_b_sel_w == 2'd1) ? operand_mux : reg_rd_data;
    // Data output mux: PUSH=reg, JAL/TRAP S2=PCH, JAL/TRAP S3=PCL, TRAP S4=flags
    wire is_trap = (ir_opcode == 8'hF5);
    wire is_jal_op = (ir_opcode == 8'h3D);
    assign data_out = (ir_opcode == 8'h2C) ? reg_rd_data :
                      ((is_jal_op || is_trap) && state == 3'd2) ? pc_out[15:8] :
                      ((is_jal_op || is_trap) && state == 3'd3) ? pc_out[7:0] :
                      (is_trap && state == 3'd4) ? {4'd0, flag_ie, flag_n, flag_c, flag_z} :
                      a0_out;

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
    wire flags_restore = (state == 3'd2 && doing_rti); // RTI S2: restore flags from stack
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flag_z <= 0; flag_c <= 0; flag_n <= 0; flag_ie <= 0;
        end else begin
            if (flags_we) begin
                flag_z <= alu_zero;
                flag_c <= alu_cout;
                flag_n <= alu_neg;
            end
            if (flags_restore) begin
                flag_z <= data_in[0];
                flag_c <= data_in[1];
                flag_n <= data_in[2];
                flag_ie <= data_in[3];
            end
            if (ie_set) flag_ie <= 1;
            if (ie_clr) flag_ie <= 0;
            if (ir_opcode == 8'hF0 && state == 3'd1) flag_c <= 0; // CLC
            if (ir_opcode == 8'hF1 && state == 3'd1) flag_c <= 1; // SEC
        end
    end

    // NMI edge detect
    reg nmi_prev;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            nmi_pending <= 0; nmi_prev <= 1;
            vector_addr <= 16'hFFFC; // Reset vector
        end else begin
            nmi_prev <= nmi_n;
            if (nmi_prev && !nmi_n) nmi_pending <= 1; // falling edge
            if (int_enter) begin
                nmi_pending <= 0;
                if (nmi_pending)
                    vector_addr <= 16'hFFFA; // NMI vector
                else
                    vector_addr <= 16'hFFFE; // IRQ vector
            end
            // TRAP sets vector
            if (state == 3'd1 && ir_opcode == 8'hF5)
                vector_addr <= 16'hFFF6; // TRAP vector
        end
    end

    // Module instances
    // Track instruction type across multi-cycle operations
    reg doing_jal, doing_ret, doing_rti, doing_trap;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin doing_jal <= 0; doing_ret <= 0; doing_rti <= 0; doing_trap <= 0; end
        else if (state == 3'd1) begin
            doing_jal <= (ir_opcode == 8'h3D);
            doing_ret <= (ir_opcode == 8'h3E);
            doing_rti <= (ir_opcode == 8'hF4);
            doing_trap <= (ir_opcode == 8'hF5);
        end
    end

    // PC load value:
    // JMP (S1): ptr_out
    // JAL (S4): ptr_out  
    // Vector fetch (S6), RTI (S4), RET (S3): {data_in, ir_opcode}
    wire [15:0] pc_load_val = (doing_jal || state == 3'd1) ? ptr_out : {data_in, ir_opcode};

    rv8_pc PC (
        .clk(clk), .rst_n(rst_n),
        .inc(pc_inc), .load(pc_load), .branch(pc_branch),
        .load_val(pc_load_val), .offset(operand_mux),
        .pc(pc_out)
    );

    rv8_pointer PTR (
        .clk(clk), .rst_n(rst_n),
        .load_pl(reg_we && (wr_sel == 3'd3)),
        .load_ph(reg_we && (wr_sel == 3'd4)),
        .inc16(ptr_inc), .dec16(ptr_dec), .add_imm(ptr_add),
        .data_in(ptr_add ? operand_mux : alu_result),
        .ptr_out(ptr_out), .pl_out(pl_out), .ph_out(ph_out)
    );

    // Register write data: from memory for loads/POP (S2), from ALU otherwise
    wire [7:0] reg_wr_data = (state == 3'd2 && mem_rd) ? data_in : alu_result;

    rv8_regfile REGS (
        .clk(clk), .rst_n(rst_n),
        .we(reg_we), .wr_sel(wr_sel),
        .rd_sel(operand_mux[2:0]),
        .wr_data(reg_wr_data),
        .sp_inc(sp_inc), .sp_dec(sp_dec),
        .rd_data(reg_rd_data),
        .a0_out(a0_out), .sp_out(sp_out), .pg_out(pg_out),
        .const_sel(operand_mux[4:3])
    );

    // Carry input: ADC/SBC/ROL/ROR use flag_c; ADD/ADDI force 0; SUB/SUBI/CMP/CMPI force 1
    wire alu_carry_in = (ir_opcode == 8'h06 || ir_opcode == 8'h07 ||
                         ir_opcode == 8'h42 || ir_opcode == 8'h43) ? flag_c :
                        (ir_opcode == 8'h01 || ir_opcode == 8'h05 ||
                         ir_opcode == 8'h17 || ir_opcode == 8'h18) ? 1'b1 : 1'b0;

    rv8_alu ALU (
        .a(alu_a), .b(alu_b), .op(alu_op),
        .carry_in(alu_carry_in),
        .result(alu_result),
        .carry_out(alu_cout), .zero(alu_zero), .negative(alu_neg)
    );

    // Operand: during S1, the operand byte is on data_in (not yet latched)
    // After S1, it's in ir_operand
    wire [7:0] operand_mux = (state == 3'd1) ? data_in : ir_operand;

    rv8_control CTRL (
        .clk(clk), .rst_n(rst_n),
        .opcode(ir_opcode), .operand(operand_mux),
        .flag_z(flag_z), .flag_c(flag_c), .flag_n(flag_n), .flag_ie(flag_ie),
        .nmi_pending(nmi_pending), .irq_pending(~irq_n),
        .reg_we(reg_we), .mem_rd(mem_rd), .mem_wr(mem_wr),
        .alu_op(alu_op), .addr_src(addr_src),
        .wr_sel(wr_sel), .alu_b_sel(alu_b_sel_w),
        .pc_inc(pc_inc), .pc_load(pc_load), .pc_branch(pc_branch),
        .flags_we(flags_we), .ptr_inc(ptr_inc), .ptr_dec(ptr_dec), .ptr_add(ptr_add),
        .sp_inc(sp_inc), .sp_dec(sp_dec),
        .ir_load0(ir_load0), .ir_load1(ir_load1),
        .halt_out(halt_out), .ie_set(ie_set), .ie_clr(ie_clr),
        .skip_set(skip_set), .int_enter(int_enter),
        .state_out(state)
    );
endmodule
