// ==================================================
//  * Filename      : alarm.v
//  * Description   : 알람 시각 저장 (시/분/초)            [9주차 alarm.v 수정]
//
//  9주차 alarm 과 달라진 점
//   1) 시(hour) 카운터 추가, 리셋하면 07:00:00
//   2) 입력을 팀원 hms_cnt 와 같은 형태로 맞춤
//        i_set  : 1 이면 설정 중 (top 에서 mode == ALARM_SET)
//        i_targ : 2'd0 초, 2'd1 분, 2'd2 시   (ctrl 의 o_targ)
//        i_inc / i_dec : ctrl 의 증가/감소 1클럭 펄스
//   3) 알람 시각 비교(울림)는 ring_ctrl.v 에서 함
// ==================================================
module  alarm
(
    output      [5:0]   o_hour,
    output      [5:0]   o_min,
    output      [5:0]   o_sec,
    input               i_set,
    input       [1:0]   i_targ,
    input               i_inc,
    input               i_dec,
    input               i_clk,
    input               i_rstn
);
    localparam  TARG_SEC    = 2'd0;
    localparam  TARG_MIN    = 2'd1;
    localparam  TARG_HOUR   = 2'd2;

    wire    sel_sec  = i_set & (i_targ == TARG_SEC );
    wire    sel_min  = i_set & (i_targ == TARG_MIN );
    wire    sel_hour = i_set & (i_targ == TARG_HOUR);

    alarm_cnt
    #(
        .MAX            (59             ),
        .INIT           (0              )
    )
    u_alarm_cnt_sec(
        .o_cnt          (o_sec          ),
        .i_inc          (sel_sec  & i_inc),
        .i_dec          (sel_sec  & i_dec),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    alarm_cnt
    #(
        .MAX            (59             ),
        .INIT           (0              )
    )
    u_alarm_cnt_min(
        .o_cnt          (o_min          ),
        .i_inc          (sel_min  & i_inc),
        .i_dec          (sel_min  & i_dec),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    alarm_cnt
    #(
        .MAX            (23             ),
        .INIT           (7              )
    )
    u_alarm_cnt_hour(
        .o_cnt          (o_hour         ),
        .i_inc          (sel_hour & i_inc),
        .i_dec          (sel_hour & i_dec),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );
endmodule
