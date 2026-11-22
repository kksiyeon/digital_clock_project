// 수업 8주차 debouncer.v / debouncer_nco.v (ctrl 에서 ctrl_debouncer 로 사용)
module  ctrl_debouncer_nco
#(
    parameter       FREQDIV = 50000000
)
(
    output reg      o_clk,
    input           i_clk,
    input           i_rstn
);
    reg [$clog2(FREQDIV/2)-1:0] cnt;
    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            cnt     <= (2**$clog2(FREQDIV/2)) - 1;
            o_clk   <= 0;
        end else begin
            if(cnt >= FREQDIV/2 - 1) begin
                cnt     <= 0;
                o_clk   <= ~o_clk;
            end else begin
                cnt     <= cnt + 1;
                o_clk   <= o_clk;
            end
        end
    end
endmodule

module  ctrl_debouncer
#(
    parameter       FREQDIV = 5000000
)
(
    output      [7:0]   o_sw,
    input       [7:0]   i_sw,
    input               i_clk,
    input               i_rstn
);
    wire                slow_clk;
    ctrl_debouncer_nco
    #(
        .FREQDIV        (FREQDIV        )
    )
    u_debouncer_nco(
        .o_clk          (slow_clk       ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );
    reg         [7:0]   n1;
    reg         [7:0]   n2;
    always @(posedge slow_clk) begin
        n1  <= i_sw;
        n2  <= n1;
    end
    assign      o_sw    = n1 | ~n2;
endmodule
