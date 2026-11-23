// ==================================================
//  * Filename      : timer_cnt.v
//  * Description   : 타이머 다운 카운터            [신규 - 수업 clock_cnt 를 감소 방향으로 변형]
//
//  - i_load : 설정값(i_load_val) 불러오기 (타이머 시작할 때)
//  - i_en   : 1클럭 펄스면 -1. 0 에서 감소하면 MAX 로 가고 o_borrow 펄스
//             -> o_borrow 를 윗자리 i_en 에 연결 (수업 clock_cnt 의 o_max 와 반대 방향)
//  - 예) 00:03:00 -> 초 0->59 + borrow -> 분 3->2  => 00:02:59
// ==================================================
module  timer_cnt
#(
    parameter   MAX = 59
)
(
    output reg  [5:0]   o_cnt,
    output reg          o_borrow,
    input               i_load,
    input       [5:0]   i_load_val,
    input               i_en,
    input               i_clk,
    input               i_rstn
);
    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            o_cnt       <= 6'd0;
            o_borrow    <= 1'b0;
        end else begin
            o_borrow    <= 1'b0;
            if(i_load) begin
                o_cnt   <= i_load_val;
            end else if(i_en) begin
                if(o_cnt == 6'd0) begin
                    o_cnt       <= MAX;
                    o_borrow    <= 1'b1;
                end else begin
                    o_cnt       <= o_cnt - 6'd1;
                end
            end
        end
    end
endmodule
