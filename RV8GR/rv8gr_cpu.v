// RV8-GR CPU — Behavioral Verilog Model
// 21 logic chips, no microcode, 3-cycle execution
// AC (accumulator) hardwired to ALU A, registers in RAM ($00-$07)

module rv8gr_cpu (
    input  wire        clk,
    input  wire        rst_n,
    output reg  [15:0] addr_bus,
    output reg         rom_ce_n,
    output reg         ram_ce_n,
    output reg         ram_we_n,
    inout  wire [7:0]  data_bus,
    output wire        halted
);

    // State counter: 2-bit, 3 states (00, 01, 10)
    localparam STATE_FETCH_CTRL = 2'b00;
    localparam STATE_FETCH_OPER = 2'b01;
    localparam STATE_EXECUTE    = 2'b10;

    reg [1:0]  state;
    reg [15:0] pc;
    reg [7:0]  ac;
    reg [7:0]  ir_high;
    reg [7:0]  ir_low;
    reg        z_flag;
    reg        halt;

    // Control byte decode
    wire alu_sub     = ir_high[7];
    wire xor_mode    = ir_high[6];
    wire mux_sel     = ir_high[5];
    wire ac_wr       = ir_high[4];
    wire source_type = ir_high[3];
    wire store       = ir_high[2];
    wire branch      = ir_high[1];
    wire jump        = ir_high[0];

    // ROM and RAM
    reg [7:0] rom [0:65535];
    reg [7:0] ram [0:255];

    // Data bus (active low accent)
    reg [7:0] data_out;
    reg       data_oe;
    assign data_bus = data_oe ? data_out : 8'bz;
    assign halted = halt;

    // Combinational: IBUS value during execute
    wire [7:0] ibus = source_type ? ram[ir_low] : ir_low;

    // ALU combinational
    wire [7:0] xor_b = alu_sub ? (ibus ^ 8'hFF) : ibus;
    wire [7:0] adder_result = ac + xor_b + {7'b0, alu_sub};
    wire [7:0] xor_result = ac ^ ibus;
    wire [7:0] alu_result = xor_mode ? xor_result : adder_result;
    wire [7:0] ac_d_input = mux_sel ? ibus : alu_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_FETCH_CTRL;
            pc <= 16'h8000;
            ac <= 8'h00;
            ir_high <= 8'h00;
            ir_low <= 8'h00;
            z_flag <= 1'b1;
            halt <= 1'b0;
            data_oe <= 1'b0;
            data_out <= 8'h00;
            addr_bus <= 16'h0000;
            rom_ce_n <= 1'b1;
            ram_ce_n <= 1'b1;
            ram_we_n <= 1'b1;
        end else if (!halt) begin
            case (state)
                STATE_FETCH_CTRL: begin
                    ir_high <= rom[pc[15:0] - 16'h8000];
                    pc <= pc + 1;
                    state <= STATE_FETCH_OPER;
                end

                STATE_FETCH_OPER: begin
                    ir_low <= rom[pc[15:0] - 16'h8000];
                    pc <= pc + 1;
                    state <= STATE_EXECUTE;
                end

                STATE_EXECUTE: begin
                    // ECALL (halt)
                    if (ir_high == 8'h00 && ir_low == 8'h00) begin
                        halt <= 1'b1;
                    end else begin
                        // Store: write AC to RAM
                        if (store)
                            ram[ir_low] <= ac;

                        // AC write
                        if (ac_wr) begin
                            ac <= ac_d_input;
                            z_flag <= (ac_d_input == 8'h00);
                        end

                        // Branch: ALU_SUB inverts condition (BEQ: Z=1, BNE: Z=0)
                        if (branch) begin
                            if (z_flag ^ alu_sub)
                                pc <= {8'h80, ir_low};
                        end

                        // Jump: unconditional
                        if (jump)
                            pc <= {8'h80, ir_low};
                    end

                    state <= STATE_FETCH_CTRL;
                end

                default: state <= STATE_FETCH_CTRL;
            endcase
        end
    end

endmodule
