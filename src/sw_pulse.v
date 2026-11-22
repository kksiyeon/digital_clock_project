// ==================================================
//  * Filename      : sw_pulse.v
//  * Description   : 수업 debouncer 출력(sw) -> i_clk 1클럭 펄스
//
//  수업 debouncer 의 o_sw 는 평소 1, 버튼을 누르면 약 0.1초 동안 0 이 됩니다.
//  (DE0-Nano 확장 스위치: 평소 '1', 누르면 '0' — pull-up)
//  이 0 구간이 시작되는 순간을 50MHz 클럭 기준 "딱 1클럭" 펄스로 바꿉니다.
// ==================================================
module  sw_pulse
#(
    parameter   N = 8
)
(
    output      [N-1:0] o_pulse,
    input       [N-1:0] i_sw,       // debouncer 의 o_sw (active-low)
    input               i_clk,
    input               i_rstn
);
    reg [N-1:0] s1, s2, s3;
    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            s1 <= {N{1'b0}};
            s2 <= {N{1'b0}};
            s3 <= {N{1'b0}};
        end else begin
            s1 <= ~i_sw;    // 눌림 = 1 로 뒤집기 + 동기화
            s2 <= s1;
            s3 <= s2;
        end
    end
    assign  o_pulse = s2 & ~s3;     // 0 -> 1 되는 순간
endmodule
