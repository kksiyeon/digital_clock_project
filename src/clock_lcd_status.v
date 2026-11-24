`timescale 1ns/1ps
module clock_lcd_status #(
    parameter integer CLK_HZ = 50000000
) (
    input i_clk, i_rstn,
    input [1:0] i_mode,
    input [5:0] i_alarm_hour, i_alarm_min, i_alarm_sec,
    input i_alarm_en,
    output o_lcd_rs, o_lcd_rw, o_lcd_e,
    output [7:0] o_lcd_data
);
    function [15:0] ascii_pair;
        input [5:0] value;
        reg [3:0] tens, ones;
        begin
            tens = value / 6'd10;
            ones = value % 6'd10;
            ascii_pair = {4'h3, tens, 4'h3, ones};
        end
    endfunction

    reg [127:0] line1;
    always @* begin
        case (i_mode)
            2'b00: line1 = "NORMAL          ";
            2'b01: line1 = "CLOCK SET       ";
            2'b10: line1 = "ALARM SET       ";
            2'b11: line1 = "TIMER           ";
            default: line1 = "                ";
        endcase
    end
    wire [127:0] line2 = {"AL ", ascii_pair(i_alarm_hour), ":",
                          ascii_pair(i_alarm_min), ":", ascii_pair(i_alarm_sec),
                          " ", (i_alarm_en ? "ON  " : "OFF ")};

    text_lcd #(.CLK_HZ(CLK_HZ)) u_lcd (
        .clk(i_clk), .rst_n(i_rstn), .line1(line1), .line2(line2),
        .rs(o_lcd_rs), .rw(o_lcd_rw), .e(o_lcd_e), .data(o_lcd_data)
    );
endmodule
