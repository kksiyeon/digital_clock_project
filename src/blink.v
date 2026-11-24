// ==================================================
//  * Filename      : blink.v
//  * Description   : 설정 중인 칸(시/분/초)을 깜빡이게 함
//
//  arbiter 와 ssegdisp 사이에 끼워 넣는 모듈입니다.
//    arbiter.o_num0~5 --> [blink] --> ssegdisp.i_num0~5
//  꺼지는 구간에는 숫자 대신 4'd15 를 내보내고, 수업 ssegdisp_dec 는
//  0~9 외의 값(default)을 7'b000_0000 (전부 꺼짐)으로 표시하므로 그 자리가 꺼집니다.
//  ※ a~f 까지 표시하는 decoder 버전을 쓰면 'F' 가 보이니, 15 -> 공백인 버전을 쓰세요.
//
//  자리 배치(수업 arbiter 와 동일): num1,num0 = 초 / num3,num2 = 분 / num5,num4 = 시
//  i_en    : 1 이면 깜빡임 (시계설정/알람설정/타이머설정 중일 때 1)
//  i_targ  : 2'd0 초, 2'd1 분, 2'd2 시  (ctrl 의 o_targ)
//  i_hold  : 1클럭 펄스. 버튼 누를 때 넣으면 바로 '켜짐'으로 돌아가서
//            값을 바꾸는 순간 숫자가 안 보이는 일이 없음
// ==================================================
module  blink
#(
    parameter   FREQDIV = 50000000/2    // 50MHz/2 = 0.5초마다 토글 -> 1Hz 깜빡임
)
(
    output      [3:0]   o_num0,
    output      [3:0]   o_num1,
    output      [3:0]   o_num2,
    output      [3:0]   o_num3,
    output      [3:0]   o_num4,
    output      [3:0]   o_num5,
    input       [3:0]   i_num0,
    input       [3:0]   i_num1,
    input       [3:0]   i_num2,
    input       [3:0]   i_num3,
    input       [3:0]   i_num4,
    input       [3:0]   i_num5,
    input               i_en,
    input       [1:0]   i_targ,
    input               i_hold,
    input               i_clk,
    input               i_rstn
);
    localparam  BLANK   = 4'd15;

    reg [$clog2(FREQDIV)-1:0]   cnt;
    reg                         show;   // 1 = 켜짐 구간

    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            cnt     <= 0;
            show    <= 1'b1;
        end else if(!i_en || i_hold) begin
            cnt     <= 0;
            show    <= 1'b1;
        end else if(cnt >= FREQDIV - 1) begin
            cnt     <= 0;
            show    <= ~show;
        end else begin
            cnt     <= cnt + 1;
        end
    end

    wire    off_sec  = i_en & ~show & (i_targ == 2'd0);
    wire    off_min  = i_en & ~show & (i_targ == 2'd1);
    wire    off_hour = i_en & ~show & (i_targ == 2'd2);

    assign  o_num0 = off_sec  ? BLANK : i_num0;
    assign  o_num1 = off_sec  ? BLANK : i_num1;
    assign  o_num2 = off_min  ? BLANK : i_num2;
    assign  o_num3 = off_min  ? BLANK : i_num3;
    assign  o_num4 = off_hour ? BLANK : i_num4;
    assign  o_num5 = off_hour ? BLANK : i_num5;
endmodule
