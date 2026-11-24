`timescale 1ns/1ps
// HD44780-compatible 16x2, 8-bit write only. Snapshot both lines per refresh.
module text_lcd #(
    parameter integer CLK_HZ = 50000000,
    parameter integer UNIT_CYCLES = (CLK_HZ+49999)/50000 // >=20 us
) (
    input clk, rst_n,
    input [127:0] line1, line2,
    output reg rs, e,
    output rw,
    output reg [7:0] data
);
    localparam BOOT=0, LOAD=1, SETUP=2, ENABLE=3, HOLD=4, WAIT_CHANGE=5;
    localparam integer UNIT_W = (UNIT_CYCLES < 2) ? 1 : $clog2(UNIT_CYCLES);
    reg [UNIT_W-1:0] subcount;
    reg [11:0] delay_units;
    reg [2:0] state, init_step;
    reg initialized;
    reg [5:0] pos;
    reg [255:0] text_frame;
    wire [3:0] char_idx = (pos < 17) ? pos - 1'b1 : pos - 6'd18;
    assign rw = 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            subcount <= 0; delay_units <= 2499; state <= BOOT;
            init_step <= 0; initialized <= 0; pos <= 0; text_frame <= 0;
            rs <= 0; e <= 0; data <= 0;
        end else if (subcount != UNIT_CYCLES-1) subcount <= subcount + 1'b1;
        else begin
            subcount <= 0;
            if (delay_units != 0) delay_units <= delay_units - 1'b1;
            else case (state)
                BOOT: if (!initialized) state <= LOAD;
                else begin
                    rs <= (pos != 0 && pos != 17);
                    if (pos == 0) data <= 8'h80;
                    else if (pos == 17) data <= 8'hC0;
                    else if (pos < 17) data <= text_frame[255-char_idx*8 -: 8];
                    else data <= text_frame[127-char_idx*8 -: 8];
                    state <= SETUP;
                end
                LOAD: begin
                    rs <= 0;
                    case (init_step)
                        0,1,2: data <= 8'h30;
                        3: data <= 8'h38; // 8-bit, 2 lines
                        4: data <= 8'h08; // display off
                        5: data <= 8'h01; // clear
                        6: data <= 8'h06; // entry mode
                        7: data <= 8'h0C; // display on
                    endcase
                    state <= SETUP;
                end
                SETUP: begin e <= 1; state <= ENABLE; end
                ENABLE: begin e <= 0; state <= HOLD; end
                HOLD: begin
                    if (!initialized) begin
                        if (init_step == 0) delay_units <= 250; // 5 ms after first wake
                        else if (init_step == 1) delay_units <= 6; // 120 us after second wake
                        else if (init_step == 5) delay_units <= 100; // 2 ms after clear
                        if (init_step == 7) begin initialized <= 1; state <= WAIT_CHANGE; end
                        else begin init_step <= init_step + 1'b1; state <= LOAD; end
                    end else if (pos == 33) state <= WAIT_CHANGE;
                    else begin pos <= pos + 1'b1; state <= BOOT; end
                end
                WAIT_CHANGE: if (text_frame != {line1,line2}) begin
                    text_frame <= {line1,line2}; pos <= 0; state <= BOOT;
                end
                default: state <= WAIT_CHANGE;
            endcase
        end
    end
endmodule
