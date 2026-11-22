// ==================================================
//  * Filename      : updn_cnt.v
//  * Description   : 증가/감소 카운터 (수업 clock_cnt 의 업그레이드 버전)
//
//  - 수업 clock_cnt 는 스위치 신호를 i_clk 로 직접 넣어서 +1 만 했지만,
//    감소(-1)를 추가하려면 "방향" 신호가 클럭과 동시에 바뀌어서 타이밍이 꼬입니다.
//    그래서 50MHz i_clk 하나로 돌리고, i_inc / i_dec 를 "1클럭 펄스"로 받습니다.
//  - 0 에서 감소하면 MAX 로, MAX 에서 증가하면 0 으로 순환.
//  - o_wrap_up : 이번 클럭에 MAX -> 0 으로 넘어감 (수업 o_max 역할, 윗자리 +1 용)
//  - o_wrap_dn : 이번 클럭에 0 -> MAX 로 넘어감 (타이머처럼 내려갈 때 윗자리 -1 용)
// ==================================================
module  updn_cnt
#(
    parameter   MAX = 59
)
(
    output reg  [5:0]   o_cnt,
    output              o_wrap_up,
    output              o_wrap_dn,
    input               i_inc,      // 1클럭 펄스: +1
    input               i_dec,      // 1클럭 펄스: -1  (동시에 오면 무시)
    input               i_clk,
    input               i_rstn
);
    wire    inc = i_inc & ~i_dec;
    wire    dec = i_dec & ~i_inc;

    assign  o_wrap_up = inc & (o_cnt == MAX);
    assign  o_wrap_dn = dec & (o_cnt == 6'd0);

    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            o_cnt   <= 6'd0;
        end else if(inc) begin
            o_cnt   <= (o_cnt >= MAX) ? 6'd0 : o_cnt + 6'd1;
        end else if(dec) begin
            o_cnt   <= (o_cnt == 6'd0 || o_cnt > MAX) ? MAX : o_cnt - 6'd1;
        end
    end
endmodule
