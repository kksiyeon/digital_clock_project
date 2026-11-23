// ==================================================
//  * Filename      : alarm_cnt.v
//  * Description   : 알람/타이머 설정값 카운터          [9주차 alarm_cnt.v 수정]
//
//  9주차 alarm_cnt 와 달라진 점
//   1) 스위치 신호를 클럭으로 쓰지 않고 50MHz i_clk + 1클럭 펄스(i_inc / i_dec)로 동작
//      (팀원 updn_cnt 와 같은 방식 -> 감소 버튼을 같이 쓸 수 있음)
//   2) 감소 기능 추가: 0 에서 감소하면 MAX 로
//   3) 리셋 값(INIT) 파라미터 추가 -> 알람 기본 07:00:00, 타이머 기본 00:03:00
//   4) 출력은 팀원 hms_cnt 와 같은 6비트
// ==================================================
module  alarm_cnt
#(
    parameter   MAX  = 59,
    parameter   INIT = 0
)
(
    output reg  [5:0]   o_cnt,
    input               i_inc,      // 1클럭 펄스: +1
    input               i_dec,      // 1클럭 펄스: -1  (동시에 오면 무시)
    input               i_clk,
    input               i_rstn
);
    wire    inc = i_inc & ~i_dec;
    wire    dec = i_dec & ~i_inc;

    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            o_cnt   <= INIT;
        end else if(inc) begin
            o_cnt   <= (o_cnt >= MAX) ? 6'd0 : o_cnt + 6'd1;
        end else if(dec) begin
            o_cnt   <= (o_cnt == 6'd0 || o_cnt > MAX) ? MAX : o_cnt - 6'd1;
        end
    end
endmodule
