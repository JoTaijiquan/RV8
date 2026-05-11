// RV8 UART — Simple bit-bang serial I/O port
// Memory-mapped: $8000 = data, $8001 = status
// Status: bit0 = RX ready, bit1 = TX busy
module rv8_uart (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] addr,
    input  wire [7:0] data_in,
    output reg  [7:0] data_out,
    input  wire       io_rd,
    input  wire       io_wr,
    input  wire       serial_rx,
    output reg        serial_tx,
    output wire       rx_ready
);
    reg [7:0] rx_data;
    reg       rx_flag;
    assign rx_ready = rx_flag;

    // RX shift register
    reg [3:0] rx_bit;
    reg [7:0] rx_shift;
    reg       rx_active;
    reg [15:0] rx_timer;
    parameter CLK_DIV = 304; // 3.5MHz / 115200 * 10 ~= 304

    // TX shift register
    reg [3:0] tx_bit;
    reg [9:0] tx_shift;
    reg       tx_active;
    reg [15:0] tx_timer;

    // RX logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_flag <= 0; rx_active <= 0;
            rx_bit <= 0; rx_timer <= 0;
            serial_tx <= 1; tx_active <= 0;
            tx_bit <= 0; tx_timer <= 0;
        end else begin
            // RX: detect start bit
            if (!rx_active && !serial_rx) begin
                rx_active <= 1;
                rx_timer <= CLK_DIV / 2;
                rx_bit <= 0;
            end else if (rx_active) begin
                if (rx_timer == 0) begin
                    rx_timer <= CLK_DIV;
                    if (rx_bit == 9) begin
                        rx_data <= rx_shift;
                        rx_flag <= 1;
                        rx_active <= 0;
                    end else if (rx_bit > 0) begin
                        rx_shift <= {serial_rx, rx_shift[7:1]};
                    end
                    rx_bit <= rx_bit + 1;
                end else
                    rx_timer <= rx_timer - 1;
            end
            // TX
            if (tx_active) begin
                if (tx_timer == 0) begin
                    tx_timer <= CLK_DIV;
                    serial_tx <= tx_shift[0];
                    tx_shift <= {1'b1, tx_shift[9:1]};
                    tx_bit <= tx_bit + 1;
                    if (tx_bit == 10) tx_active <= 0;
                end else
                    tx_timer <= tx_timer - 1;
            end
            // Bus read clears rx_flag
            if (io_rd && addr == 8'h00) rx_flag <= 0;
            // Bus write starts TX
            if (io_wr && addr == 8'h00) begin
                tx_shift <= {1'b1, data_in, 1'b0};
                tx_active <= 1; tx_bit <= 0; tx_timer <= 0;
            end
        end
    end

    // Read mux
    always @(*) begin
        case (addr)
            8'h00: data_out = rx_data;
            8'h01: data_out = {6'b0, tx_active, rx_flag};
            default: data_out = 8'hFF;
        endcase
    end
endmodule
