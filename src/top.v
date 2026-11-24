// ==================================================
//  * Filename      : top.v
//  * Description   : 시계 + 설정(증가/감소) + blink 연결 예시 top
//
//  이 top 하나만으로도 보드에서 "시:분:초 시계 + 설정 + 감소 + 깜빡임"이 동작합니다.
//  알람/타이머는 같은 hms_cnt 를 재사용한 '자리만 잡아둔' 버전이고,
//  실제 알람 비교/부저/타이머 종료는 알람·타이머 모듈, 리모콘/LCD/PSD 는 해당 모듈을 붙이면 됩니다.
//
//  핀: 수업과 동일 (i_clk PIN_R8, i_rstn PIN_J15, i_sw[7:0], o_seg, o_seg_enb)
//      감소 버튼은 i_sw[4] (PIN_C11) 사용
// ==================================================
module  top
(
    output      [5:0]   o_seg_enb,
    output      [7:0]   o_seg,
    input       [7:0]   i_sw,
    input               i_clk,
    input               i_rstn
);
    localparam  MODE_CLOCK_OPR  = 2'b00;
    localparam  MODE_CLOCK_SET  = 2'b01;
    localparam  MODE_ALARM_SET  = 2'b10;
    localparam  MODE_TIMER      = 2'b11;

    wire    [1:0]   mode, targ;
    wire            alarm_en, inc, dec, key_any, tick_1hz;
    wire    [5:0]   clock_hour, clock_min, clock_sec;
    wire    [5:0]   alarm_hour, alarm_min, alarm_sec;
    wire    [5:0]   timer_hour, timer_min, timer_sec;
    wire            timer_zero;
    wire    [3:0]   num[0:5];
    wire    [3:0]   disp_num[0:5];

    ctrl
    u_ctrl(
        .o_mode         (mode           ),
        .o_targ         (targ           ),
        .o_alarm_en     (alarm_en       ),
        .o_inc          (inc            ),
        .o_dec          (dec            ),
        .o_key_any      (key_any        ),
        .o_tick_1hz     (tick_1hz       ),
        .i_ext_key      (5'd0           ),  // 리모콘 연결 시 여기에
        .i_sw           (i_sw           ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    // 시계: 설정 모드에서 멈추고 증가/감소, 그 외엔 1초마다 +1
    hms_cnt
    #(
        .HOUR_MAX       (23             )
    )
    u_clock(
        .o_hour         (clock_hour     ),
        .o_min          (clock_min      ),
        .o_sec          (clock_sec      ),
        .o_zero         (               ),
        .i_set          (mode == MODE_CLOCK_SET),
        .i_targ         (targ           ),
        .i_inc          (inc            ),
        .i_dec          (dec            ),
        .i_up_tick      (tick_1hz       ),
        .i_dn_tick      (1'b0           ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    // 알람 시각 (예시: 값만 저장. 비교/부저는 알람 모듈)
    hms_cnt
    #(
        .HOUR_MAX       (23             )
    )
    u_alarm(
        .o_hour         (alarm_hour     ),
        .o_min          (alarm_min      ),
        .o_sec          (alarm_sec      ),
        .o_zero         (               ),
        .i_set          (mode == MODE_ALARM_SET),
        .i_targ         (targ           ),
        .i_inc          (inc            ),
        .i_dec          (dec            ),
        .i_up_tick      (1'b0           ),
        .i_dn_tick      (1'b0           ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    // 타이머 (예시: TIMER 모드에서 설정만. 시작/정지/부저는 타이머 모듈)
    hms_cnt
    #(
        .HOUR_MAX       (23             )
    )
    u_timer(
        .o_hour         (timer_hour     ),
        .o_min          (timer_min      ),
        .o_sec          (timer_sec      ),
        .o_zero         (timer_zero     ),
        .i_set          (mode == MODE_TIMER),
        .i_targ         (targ           ),
        .i_inc          (inc            ),
        .i_dec          (dec            ),
        .i_up_tick      (1'b0           ),
        .i_dn_tick      (1'b0           ),  // 타이머 동작 시: tick_1hz & running & ~timer_zero
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    arbiter
    u_arbiter(
        .o_num0         (num[0]         ),
        .o_num1         (num[1]         ),
        .o_num2         (num[2]         ),
        .o_num3         (num[3]         ),
        .o_num4         (num[4]         ),
        .o_num5         (num[5]         ),
        .i_mode         (mode           ),
        .i_clock_hour   (clock_hour     ),
        .i_clock_min    (clock_min      ),
        .i_clock_sec    (clock_sec      ),
        .i_alarm_hour   (alarm_hour     ),
        .i_alarm_min    (alarm_min      ),
        .i_alarm_sec    (alarm_sec      ),
        .i_timer_hour   (timer_hour     ),
        .i_timer_min    (timer_min      ),
        .i_timer_sec    (timer_sec      )
    );

    blink
    u_blink(
        .o_num0         (disp_num[0]    ),
        .o_num1         (disp_num[1]    ),
        .o_num2         (disp_num[2]    ),
        .o_num3         (disp_num[3]    ),
        .o_num4         (disp_num[4]    ),
        .o_num5         (disp_num[5]    ),
        .i_num0         (num[0]         ),
        .i_num1         (num[1]         ),
        .i_num2         (num[2]         ),
        .i_num3         (num[3]         ),
        .i_num4         (num[4]         ),
        .i_num5         (num[5]         ),
        .i_en           (mode != MODE_CLOCK_OPR),  // [추측] 타이머 '동작 중'엔 0 이 되게 타이머 모듈과 조정
        .i_targ         (targ           ),
        .i_hold         (key_any        ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    ssegdisp
    #(
        .FREQDIV        (5000           )
    )
    u_ssegdisp(
        .o_seg_enb      (o_seg_enb      ),
        .o_seg          (o_seg          ),
        .i_num0         (disp_num[0]    ),
        .i_num1         (disp_num[1]    ),
        .i_num2         (disp_num[2]    ),
        .i_num3         (disp_num[3]    ),
        .i_num4         (disp_num[4]    ),
        .i_num5         (disp_num[5]    ),
        .i_dp0          (1'b0           ),
        .i_dp1          (1'b0           ),
        .i_dp2          (1'b1           ),  // 분.초 사이 점
        .i_dp3          (1'b0           ),
        .i_dp4          (1'b1           ),  // 시.분 사이 점
        .i_dp5          (1'b0           ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );
endmodule
