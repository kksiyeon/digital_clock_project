`timescale 1ns/1ps
// 비교기/ADC가 변환한 디지털 근접 입력만 받는다.
module clock_psd_mute #(
    parameter integer STABLE_CYCLES = 1000000, // 50 MHz에서 20 ms
    parameter ACTIVE_HIGH = 1'b1
) (
    input i_clk, i_rstn, i_psd_near, i_ringing,
    output reg o_mute
);
    localparam FAR_LEVEL = !ACTIVE_HIGH;
    localparam integer COUNT_W = STABLE_CYCLES > 1 ? $clog2(STABLE_CYCLES) : 1;
    (* ASYNC_REG = "TRUE" *) reg [1:0] sync;
    reg [COUNT_W-1:0] count;
    reg near_stable;
    wire near_now = (sync[1] == ACTIVE_HIGH);

    always @(posedge i_clk or negedge i_rstn) begin
        if (!i_rstn) begin
            sync <= {2{FAR_LEVEL}};
            near_stable <= 1'b0;
            count <= 0;
            o_mute <= 1'b0;
        end else begin
            sync <= {sync[0], i_psd_near};
            o_mute <= 1'b0;
            if (near_now == near_stable) count <= 0;
            else if (count == STABLE_CYCLES - 1) begin
                near_stable <= near_now;
                count <= 0;
                o_mute <= near_now && i_ringing;
            end else count <= count + 1'b1;
        end
    end
endmodule
