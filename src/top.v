// ==================================================
//  * Filename      : top.v
//  * Description   : 시계 + 설정(증가/감소) + blink 연결 예시 top
//
//  이 top 하나로 보드에서 "시:분:초 시계 + 설정 + 감소 + 깜빡임 + 알람 + 타이머"가 동작합니다.
//  리모콘은 ctrl에, LCD는 상태 신호에, PSD는 울림 정지에 연결합니다.
//
//  [보드 연결 정리]
//   - 거리센서: psd_adc.v 가 보드 내장 ADC128S102 를 SPI 로 읽어 '가까움' 레벨을 만들고,
//              clock_psd_mute 가 20ms 안정화 후 울림만 끔
//   - 리모콘 : 수업 10주차처럼 IR 수신기를 PIN_C9 에 연결. 이 핀은 원래 sw[0](모드) 자리라서
//              SW0_SHARED_WITH_IR=1 (기본) 이면 모드 버튼을 sw[7] (PIN_D11) 로 옮김
//              (시뮬레이션처럼 sw[0] 을 모드로 쓰려면 SW0_SHARED_WITH_IR=0)
//   - LCD    : 7-세그먼트와 핀이 겹치지 않게 GPIO-0 헤더 GPIO_0[0..10] 에 연결 (quartus/digital_clock.qsf)
//
//  [알람·타이머 추가]
//   - u_alarm : hms_cnt 자리표시 -> alarm.v (기본 07:00:00, 설정 중 증가/감소)
//   - u_timer : hms_cnt 자리표시 -> timer.v (기본 00:03:00, 시작/일시정지/리셋, 카운트다운)
//   - u_ring  : ring_ctrl.v (알람 시각 비교 + 타이머 종료 -> 부저 On/Off)
//   - u_buzzer: buzzer.v (알람 = 멜로디, 타이머 = 비프) -> o_buzzer
//   - 깜빡임  : 타이머가 '설정 상태'일 때만 깜빡임 (카운트다운 중엔 안 깜빡임)
//   - 가장 오른쪽 점(dp0) = 알람 On 표시
//
//  핀: 수업과 동일 (i_clk PIN_R8, i_rstn PIN_J15, i_sw[7:0], o_seg, o_seg_enb)
//      감소 버튼은 i_sw[4] (PIN_C11), 타이머 시작 i_sw[5] (PIN_E10), 정지 i_sw[6] (PIN_E11)
//      부저 o_buzzer = PIN_C8 (수업 9주차 부저 핀)
// ==================================================
module  top
#(
    parameter integer IO_CLK_HZ = 50000000,  // IR/LCD/PSD용; 기존 시계 분주와 별도
    parameter integer PSD_STABLE_CYCLES = (IO_CLK_HZ + 49) / 50,
    parameter PSD_ACTIVE_HIGH = 1'b1,
    parameter [2:0]  PSD_ADC_CH = 3'd0,      // 거리센서가 연결된 ADC128S102 채널
    parameter [11:0] PSD_TH_ON  = 12'd2000,  // 이 값 이상이면 가까움 (보드에서 조정)
    parameter [11:0] PSD_TH_OFF = 12'd1600,  // 이 값 이하이면 멀어짐
    parameter integer PSD_SCLK_HALF = 3,     // ADC SCLK = i_clk / (2*3) = 약 8.3MHz
    parameter SW0_SHARED_WITH_IR = 1'b1,     // 1: IR 이 sw[0] 핀(C9)을 쓰므로 모드 버튼 = sw[7]
    parameter IR_FILTER_ADDRESS = 1'b0,
    parameter [7:0] IR_ADDRESS = 8'h00,
    parameter [7:0] IR_MODE = 8'h45, IR_TARG = 8'h46, IR_INC = 8'h18,
                    IR_ALARM = 8'h47, IR_DEC = 8'h52, IR_START = 8'h40,
                    IR_STOP = 8'h44
)
(
    output      [5:0]   o_seg_enb,
    output      [7:0]   o_seg,
    output              o_buzzer,
    input       [7:0]   i_sw,
    input               i_clk,
    input               i_rstn,
    input               i_ir_n,
    output              o_adc_csn, o_adc_sclk, o_adc_din,   // ADC128S102 (거리센서)
    input               i_adc_dout,
    output              o_lcd_rs, o_lcd_rw, o_lcd_e,
    output      [7:0]   o_lcd_data
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
    wire    [1:0]   timer_state;
    wire            timer_done, timer_idle;
    wire            start, stop;
    wire            alarm_ring, timer_ring, buzzer_enb, song;
    wire    [6:0]   ir_key;
    wire            psd_mute, psd_near;
    wire    [11:0]  psd_data;
    wire    [7:0]   sw_key = SW0_SHARED_WITH_IR ? {1'b1, i_sw[6:1], i_sw[7]} : i_sw;
    wire    [3:0]   num[0:5];
    wire    [3:0]   disp_num[0:5];

    clock_ir_keys #(
        .CLK_HZ(IO_CLK_HZ), .IR_FILTER_ADDRESS(IR_FILTER_ADDRESS), .IR_ADDRESS(IR_ADDRESS),
        .IR_MODE(IR_MODE), .IR_TARG(IR_TARG), .IR_INC(IR_INC), .IR_ALARM(IR_ALARM),
        .IR_DEC(IR_DEC), .IR_START(IR_START), .IR_STOP(IR_STOP)
    ) u_ir_keys (
        .i_clk(i_clk), .i_rstn(i_rstn), .i_ir_n(i_ir_n), .o_key(ir_key)
    );

    clock_lcd_status #(.CLK_HZ(IO_CLK_HZ)) u_lcd_status (
        .i_clk(i_clk), .i_rstn(i_rstn), .i_mode(mode), .i_alarm_en(alarm_en),
        .i_alarm_hour(alarm_hour), .i_alarm_min(alarm_min), .i_alarm_sec(alarm_sec),
        .o_lcd_rs(o_lcd_rs), .o_lcd_rw(o_lcd_rw), .o_lcd_e(o_lcd_e), .o_lcd_data(o_lcd_data)
    );

    psd_adc #(.SCLK_HALF(PSD_SCLK_HALF), .CHANNEL(PSD_ADC_CH),
              .TH_ON(PSD_TH_ON), .TH_OFF(PSD_TH_OFF)) u_psd_adc (
        .o_csn(o_adc_csn), .o_sclk(o_adc_sclk), .o_din(o_adc_din),
        .o_data(psd_data), .o_valid(), .o_near(psd_near),
        .i_dout(i_adc_dout), .i_clk(i_clk), .i_rstn(i_rstn)
    );

    clock_psd_mute #(.STABLE_CYCLES(PSD_STABLE_CYCLES), .ACTIVE_HIGH(PSD_ACTIVE_HIGH)) u_psd_mute (
        .i_clk(i_clk), .i_rstn(i_rstn), .i_psd_near(psd_near),
        .i_ringing(alarm_ring | timer_ring), .o_mute(psd_mute)
    );

    ctrl
    u_ctrl(
        .o_mode         (mode           ),
        .o_targ         (targ           ),
        .o_alarm_en     (alarm_en       ),
        .o_inc          (inc            ),
        .o_dec          (dec            ),
        .o_key_any      (key_any        ),
        .o_tick_1hz     (tick_1hz       ),
        .o_start        (start          ),
        .o_stop         (stop           ),
        .i_ext_key      (ir_key          ),
        .i_sw           (sw_key         ),
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

    // 알람 시각 (ALARM_SET 모드에서 설정)
    alarm
    u_alarm(
        .o_hour         (alarm_hour     ),
        .o_min          (alarm_min      ),
        .o_sec          (alarm_sec      ),
        .i_set          (mode == MODE_ALARM_SET),
        .i_targ         (targ           ),
        .i_inc          (inc            ),
        .i_dec          (dec            ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    // 타이머 (TIMER 모드에서 설정 / 시작 / 일시정지 / 리셋, 모드를 바꿔도 계속 동작)
    //  정지 버튼: 울리는 중이면 울림만 끄고, 아니면 TIMER 모드에서 타이머 리셋
    timer
    u_timer(
        .o_hour         (timer_hour     ),
        .o_min          (timer_min      ),
        .o_sec          (timer_sec      ),
        .o_state        (timer_state    ),
        .o_done         (timer_done     ),
        .i_set          (mode == MODE_TIMER),
        .i_targ         (targ           ),
        .i_inc          (inc            ),
        .i_dec          (dec            ),
        .i_start        (start & (mode == MODE_TIMER)),
        .i_reset        (stop  & (mode == MODE_TIMER) & buzzer_enb),
        .i_tick         (tick_1hz       ),
        .i_ring         (timer_ring     ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );
    assign  timer_idle = (timer_state == 2'd0);

    // 울림 제어 (알람 시각 비교 + 타이머 종료)
    ring_ctrl
    u_ring(
        .o_buzzer_enb   (buzzer_enb     ),
        .o_song         (song           ),
        .o_alarm_ring   (alarm_ring     ),
        .o_timer_ring   (timer_ring     ),
        .i_alarm_en     (alarm_en       ),
        .i_clock_setting(mode == MODE_CLOCK_SET),
        .i_clock_hour   (clock_hour     ),
        .i_clock_min    (clock_min      ),
        .i_clock_sec    (clock_sec      ),
        .i_alarm_hour   (alarm_hour     ),
        .i_alarm_min    (alarm_min      ),
        .i_alarm_sec    (alarm_sec      ),
        .i_timer_done   (timer_done     ),
        .i_stop         (stop | psd_mute),  // PSD는 울림만 정지, 타이머 리셋과 분리
        .i_tick_1s      (tick_1hz       ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    // 부저 (알람 = 환희의 송가, 타이머 = 비프)
    buzzer
    u_buzzer(
        .o_out          (o_buzzer       ),
        .i_enb          (buzzer_enb     ),
        .i_song         (song           ),
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
        .i_en           ((mode == MODE_CLOCK_SET) | (mode == MODE_ALARM_SET) |
                         ((mode == MODE_TIMER) & timer_idle)),  // 타이머는 설정 상태일 때만
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
        .i_dp0          (alarm_en       ),  // 알람 On 표시
        .i_dp1          (1'b0           ),
        .i_dp2          (1'b1           ),  // 분.초 사이 점
        .i_dp3          (1'b0           ),
        .i_dp4          (1'b1           ),  // 시.분 사이 점
        .i_dp5          (1'b0           ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );
endmodule
