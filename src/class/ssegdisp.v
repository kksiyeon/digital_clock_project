// 수업 8주차 ssegdisp.v 와 하위 모듈 (dec 는 0~9 + default 꺼짐 버전)
module  ssegdisp_nco
#(
    parameter       FREQDIV = 10
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

module  ssegdisp_upcnt
#(
    parameter   UPBND   = 15
)
(
    output reg  [$clog2(UPBND+1)-1:0]   o_cnt,
    input                               i_clk,
    input                               i_rstn
);
    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            o_cnt   <= UPBND;
        end else begin
            if(o_cnt == UPBND) o_cnt <= 0;
            else               o_cnt <= o_cnt + 1;
        end
    end
endmodule

module  ssegdisp_enabler
(
    output reg  [5:0]   o_seg_enb,
    input       [2:0]   i_cnt
);
    always @(*) begin
        case(i_cnt)
            3'd0:   o_seg_enb = 6'b111110;
            3'd1:   o_seg_enb = 6'b111101;
            3'd2:   o_seg_enb = 6'b111011;
            3'd3:   o_seg_enb = 6'b110111;
            3'd4:   o_seg_enb = 6'b101111;
            3'd5:   o_seg_enb = 6'b011111;
            default:o_seg_enb = 6'b111111;
        endcase
    end
endmodule

module  ssegdisp_dec
(
    output reg  [7:0]   o_seg,
    input       [3:0]   i_num,
    input               i_dp
);
    always @(*) begin
        case(i_num)
            4'h0:   o_seg = {7'b111_1110, i_dp};
            4'h1:   o_seg = {7'b011_0000, i_dp};
            4'h2:   o_seg = {7'b110_1101, i_dp};
            4'h3:   o_seg = {7'b111_1001, i_dp};
            4'h4:   o_seg = {7'b011_0011, i_dp};
            4'h5:   o_seg = {7'b101_1011, i_dp};
            4'h6:   o_seg = {7'b101_1111, i_dp};
            4'h7:   o_seg = {7'b111_0000, i_dp};
            4'h8:   o_seg = {7'b111_1111, i_dp};
            4'h9:   o_seg = {7'b111_0011, i_dp};
            default:o_seg = {7'b000_0000, i_dp};
        endcase
    end
endmodule

module ssegdisp_mux6
(
    output reg  [7:0]   o_out,
    input       [7:0]   i_in0,
    input       [7:0]   i_in1,
    input       [7:0]   i_in2,
    input       [7:0]   i_in3,
    input       [7:0]   i_in4,
    input       [7:0]   i_in5,
    input       [2:0]   i_sel
);
    always  @(*) begin
        case (i_sel)
            3'd0    :   o_out = i_in0;
            3'd1    :   o_out = i_in1;
            3'd2    :   o_out = i_in2;
            3'd3    :   o_out = i_in3;
            3'd4    :   o_out = i_in4;
            3'd5    :   o_out = i_in5;
            default :   o_out = 8'd0;
        endcase
    end
endmodule

module  ssegdisp
#(
    parameter   FREQDIV = 10
)
(
    output      [5:0]   o_seg_enb,
    output      [7:0]   o_seg,
    input       [3:0]   i_num0,
    input       [3:0]   i_num1,
    input       [3:0]   i_num2,
    input       [3:0]   i_num3,
    input       [3:0]   i_num4,
    input       [3:0]   i_num5,
    input               i_dp0,
    input               i_dp1,
    input               i_dp2,
    input               i_dp3,
    input               i_dp4,
    input               i_dp5,
    input               i_clk,
    input               i_rstn
);
    wire                divclk;
    wire        [2:0]   cnt;
    wire        [7:0]   seg[0:5];
    ssegdisp_nco #(.FREQDIV(FREQDIV)) u_ssegdisp_nco(.o_clk(divclk), .i_clk(i_clk), .i_rstn(i_rstn));
    ssegdisp_upcnt #(.UPBND(5)) u_ssegdisp_upcnt(.o_cnt(cnt), .i_clk(divclk), .i_rstn(i_rstn));
    ssegdisp_enabler u_ssegdisp_enabler(.o_seg_enb(o_seg_enb), .i_cnt(cnt));
    ssegdisp_dec u_dec0(.o_seg(seg[0]), .i_num(i_num0), .i_dp(i_dp0));
    ssegdisp_dec u_dec1(.o_seg(seg[1]), .i_num(i_num1), .i_dp(i_dp1));
    ssegdisp_dec u_dec2(.o_seg(seg[2]), .i_num(i_num2), .i_dp(i_dp2));
    ssegdisp_dec u_dec3(.o_seg(seg[3]), .i_num(i_num3), .i_dp(i_dp3));
    ssegdisp_dec u_dec4(.o_seg(seg[4]), .i_num(i_num4), .i_dp(i_dp4));
    ssegdisp_dec u_dec5(.o_seg(seg[5]), .i_num(i_num5), .i_dp(i_dp5));
    ssegdisp_mux6 u_ssegdisp_mux6(.o_out(o_seg), .i_in0(seg[0]), .i_in1(seg[1]), .i_in2(seg[2]),
                                  .i_in3(seg[3]), .i_in4(seg[4]), .i_in5(seg[5]), .i_sel(cnt));
endmodule
