// ==================================================
//  * Filename      : hms_cnt.v
//  * Description   : 시:분:초 카운터 (시계 / 알람 / 타이머 공용)
//
//  수업 clock 모듈(시/분/초 clock_cnt 3개)을 대신합니다. 같은 모듈을
//  시계, 알람, 타이머에 하나씩 두고 파라미터/입력만 다르게 연결하면 됩니다.
//
//  [설정 중 (i_set = 1)]
//    i_targ 로 고른 칸만 i_inc 면 +1, i_dec 면 -1  <-- 감소 기능
//    다른 칸으로 올림/빌림 없음 (10:00 에서 '분' 감소 -> 10:59)
//  [설정 아닐 때 (i_set = 0)]
//    i_up_tick (1초 펄스) : 초 +1, 59->0 이면 분 +1 ... (시계용)
//    i_dn_tick (1초 펄스) : 초 -1, 0->59 이면 분 -1 ... (타이머용)
//    알람처럼 값이 고정이면 둘 다 0
//
//  i_targ: 2'd0 = 초, 2'd1 = 분, 2'd2 = 시   (ctrl 의 o_targ 와 동일)
// ==================================================
module  hms_cnt
#(
    parameter   HOUR_MAX = 23   // 타이머로 쓸 때 99 는 6비트 넘으니 59 이하로
)
(
    output      [5:0]   o_hour,
    output      [5:0]   o_min,
    output      [5:0]   o_sec,
    output              o_zero,     // 00:00:00 이면 1 (타이머 종료 판단용)
    input               i_set,
    input       [1:0]   i_targ,
    input               i_inc,
    input               i_dec,
    input               i_up_tick,
    input               i_dn_tick,
    input               i_clk,
    input               i_rstn
);
    localparam  TARG_SEC    = 2'd0;
    localparam  TARG_MIN    = 2'd1;
    localparam  TARG_HOUR   = 2'd2;

    wire    sec_up, sec_dn, min_up, min_dn;

    wire    sec_inc  = i_set ? (i_targ == TARG_SEC ) & i_inc : i_up_tick;
    wire    sec_dec  = i_set ? (i_targ == TARG_SEC ) & i_dec : i_dn_tick;
    wire    min_inc  = i_set ? (i_targ == TARG_MIN ) & i_inc : sec_up;
    wire    min_dec  = i_set ? (i_targ == TARG_MIN ) & i_dec : sec_dn;
    wire    hour_inc = i_set ? (i_targ == TARG_HOUR) & i_inc : min_up;
    wire    hour_dec = i_set ? (i_targ == TARG_HOUR) & i_dec : min_dn;

    updn_cnt #(.MAX(59)) u_sec (
        .o_cnt(o_sec), .o_wrap_up(sec_up), .o_wrap_dn(sec_dn),
        .i_inc(sec_inc), .i_dec(sec_dec), .i_clk(i_clk), .i_rstn(i_rstn));
    updn_cnt #(.MAX(59)) u_min (
        .o_cnt(o_min), .o_wrap_up(min_up), .o_wrap_dn(min_dn),
        .i_inc(min_inc), .i_dec(min_dec), .i_clk(i_clk), .i_rstn(i_rstn));
    updn_cnt #(.MAX(HOUR_MAX)) u_hour (
        .o_cnt(o_hour), .o_wrap_up(), .o_wrap_dn(),
        .i_inc(hour_inc), .i_dec(hour_dec), .i_clk(i_clk), .i_rstn(i_rstn));

    assign  o_zero = (o_hour == 6'd0) && (o_min == 6'd0) && (o_sec == 6'd0);
endmodule
