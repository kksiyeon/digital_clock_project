`timescale 1ns/1ps
// NEC 명령을 팀 프로젝트 ctrl.i_ext_key의 버튼 펄스로 변환한다.
//  - 한 기능에 버튼 두 개를 쓸 수 있도록 IR_TARG2 / IR_INC2 / IR_DEC2 추가
//  - 확인용: 마지막으로 받은 주소/명령(o_last_addr / o_last_cmd)과 수신 여부(o_seen)
module clock_ir_keys #(
    parameter integer CLK_HZ = 50000000,
    parameter IR_FILTER_ADDRESS = 1'b0,
    parameter [7:0] IR_ADDRESS = 8'h00,
    parameter [7:0] IR_MODE = 8'h45, IR_TARG = 8'h46, IR_INC = 8'h18,
                    IR_ALARM = 8'h47, IR_DEC = 8'h52, IR_START = 8'h40,
                    IR_STOP = 8'h44,
    parameter [7:0] IR_TARG2 = IR_TARG, IR_INC2 = IR_INC, IR_DEC2 = IR_DEC,
    parameter CHECK_ADDR_INV = 1'b0
) (
    input i_clk, i_rstn, i_ir_n,
    output reg [6:0] o_key,
    output reg [7:0] o_last_addr, o_last_cmd,
    output reg       o_seen
);
    wire valid;
    wire [7:0] address, command;
    ir_nec #(.CLK_HZ(CLK_HZ), .CHECK_ADDR_INV(CHECK_ADDR_INV)) u_nec (
        .clk(i_clk), .rst_n(i_rstn), .ir_n(i_ir_n),
        .valid(valid), .address(address), .command(command)
    );

    always @* begin
        o_key = 7'b0;
        if (valid && (!IR_FILTER_ADDRESS || address == IR_ADDRESS)) begin
            if (command == IR_MODE)                         o_key = 7'b0000001;
            else if (command == IR_TARG  || command == IR_TARG2) o_key = 7'b0000010;
            else if (command == IR_INC   || command == IR_INC2)  o_key = 7'b0000100;
            else if (command == IR_ALARM)                   o_key = 7'b0001000;
            else if (command == IR_DEC   || command == IR_DEC2)  o_key = 7'b0010000;
            else if (command == IR_START)                   o_key = 7'b0100000;
            else if (command == IR_STOP)                    o_key = 7'b1000000;
        end
    end

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            o_last_addr <= 8'd0; o_last_cmd <= 8'd0; o_seen <= 1'b0;
        end else if (valid) begin
            o_last_addr <= address; o_last_cmd <= command; o_seen <= 1'b1;
        end
    end
endmodule
