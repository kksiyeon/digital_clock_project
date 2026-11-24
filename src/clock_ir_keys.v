`timescale 1ns/1ps
// NEC 명령을 팀 프로젝트 ctrl.i_ext_key의 버튼 펄스로 변환한다.
module clock_ir_keys #(
    parameter integer CLK_HZ = 50000000,
    parameter IR_FILTER_ADDRESS = 1'b0,
    parameter [7:0] IR_ADDRESS = 8'h00,
    parameter [7:0] IR_MODE = 8'h45, IR_TARG = 8'h46, IR_INC = 8'h18,
                    IR_ALARM = 8'h47, IR_DEC = 8'h52, IR_START = 8'h40,
                    IR_STOP = 8'h44
) (
    input i_clk, i_rstn, i_ir_n,
    output reg [6:0] o_key
);
    wire valid;
    wire [7:0] address, command;
    ir_nec #(.CLK_HZ(CLK_HZ)) u_nec (
        .clk(i_clk), .rst_n(i_rstn), .ir_n(i_ir_n),
        .valid(valid), .address(address), .command(command)
    );

    always @* begin
        o_key = 7'b0;
        if (valid && (!IR_FILTER_ADDRESS || address == IR_ADDRESS)) begin
            case (command)
                IR_MODE:  o_key = 7'b0000001;
                IR_TARG:  o_key = 7'b0000010;
                IR_INC:   o_key = 7'b0000100;
                IR_ALARM: o_key = 7'b0001000;
                IR_DEC:   o_key = 7'b0010000;
                IR_START: o_key = 7'b0100000;
                IR_STOP:  o_key = 7'b1000000;
                default: ;
            endcase
        end
    end
endmodule
