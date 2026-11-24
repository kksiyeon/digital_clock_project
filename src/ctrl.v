// ==================================================
//  * Filename      : ctrl.v
//  * Description   : 모드/설정 대상 FSM + 버튼 펄스 + 1초 tick
//
//  수업 ctrl 과 달라진 점
//   1) sw[4] = 감소 버튼 추가
//   2) 모든 FSM 을 50MHz i_clk 하나로 동작 (버튼은 1클럭 펄스로 변환)
//      -> 수업처럼 "스위치를 클럭으로" 쓰지 않아서 감소 방향 타이밍 문제가 없음
//   3) 설정 대상: 초 -> 분 -> 시 (2비트), 모드 바뀌면 '초'부터 다시 시작
//   4) 1Hz '클럭' 대신 1초마다 1클럭짜리 펄스(o_tick_1hz)
//   5) 리모콘용 입력 i_ext_key: 스위치와 같은 의미의 1클럭 펄스를 넣으면 OR 됨
//
//  스위치 배치 (수업과 동일 + sw[4])
//   sw[0] 모드 / sw[1] 설정 대상 / sw[2] 증가 / sw[3] 알람 On/Off / sw[4] 감소
//
//  모드 [추측: 타이머 모드 위치는 알람·타이머 담당과 상의]
//   2'b00 CLOCK_OPR -> 2'b01 CLOCK_SET -> 2'b10 ALARM_SET -> 2'b11 TIMER -> 00 ...
// ==================================================
module  ctrl
#(
    parameter   DEB_FREQDIV = 5000000,      // 수업 debouncer 와 동일 (10Hz 샘플링)
    parameter   SEC_FREQDIV = 50000000      // 50MHz -> 1초
)
(
    output reg  [1:0]   o_mode,
    output reg  [1:0]   o_targ,
    output reg          o_alarm_en,
    output              o_inc,          // 증가 1클럭 펄스
    output              o_dec,          // 감소 1클럭 펄스
    output              o_key_any,      // 설정 관련 버튼(대상/증가/감소) 아무거나 -> blink.i_hold
    output              o_tick_1hz,     // 1초마다 1클럭 펄스
    input       [4:0]   i_ext_key,      // 리모콘 펄스 {감소, 알람, 증가, 대상, 모드}, 안 쓰면 5'd0
    input       [7:0]   i_sw,
    input               i_clk,
    input               i_rstn
);
    localparam  MODE_CLOCK_OPR  = 2'b00;
    localparam  MODE_CLOCK_SET  = 2'b01;
    localparam  MODE_ALARM_SET  = 2'b10;
    localparam  MODE_TIMER      = 2'b11;
    localparam  TARG_SEC        = 2'd0;
    localparam  TARG_MIN        = 2'd1;
    localparam  TARG_HOUR       = 2'd2;

    // ---- 디바운스 (수업 모듈 그대로) ----
    wire    [7:0]   sw;
    ctrl_debouncer
    #(
        .FREQDIV        (DEB_FREQDIV    )
    )
    u_ctrl_debouncer(
        .o_sw           (sw             ),
        .i_sw           (i_sw           ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    // ---- 버튼 -> 1클럭 펄스 ----
    wire    [7:0]   p_sw;
    sw_pulse
    #(
        .N              (8              )
    )
    u_sw_pulse(
        .o_pulse        (p_sw           ),
        .i_sw           (sw             ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );
    wire    key_mode    = p_sw[0] | i_ext_key[0];
    wire    key_targ    = p_sw[1] | i_ext_key[1];
    wire    key_inc     = p_sw[2] | i_ext_key[2];
    wire    key_alarm   = p_sw[3] | i_ext_key[3];
    wire    key_dec     = p_sw[4] | i_ext_key[4];

    assign  o_inc       = key_inc;
    assign  o_dec       = key_dec;
    assign  o_key_any   = key_targ | key_inc | key_dec;

    // ---- 모드 FSM ----
    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            o_mode  <= MODE_CLOCK_OPR;
        end else if(key_mode) begin
            case(o_mode)
                MODE_CLOCK_OPR: o_mode  <= MODE_CLOCK_SET;
                MODE_CLOCK_SET: o_mode  <= MODE_ALARM_SET;
                MODE_ALARM_SET: o_mode  <= MODE_TIMER;
                default:        o_mode  <= MODE_CLOCK_OPR;
            endcase
        end
    end

    // ---- 설정 대상 FSM (초 -> 분 -> 시) ----
    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            o_targ  <= TARG_SEC;
        end else if(key_mode) begin
            o_targ  <= TARG_SEC;                // 모드 바뀌면 초부터
        end else if(key_targ) begin
            case(o_targ)
                TARG_SEC:   o_targ  <= TARG_MIN;
                TARG_MIN:   o_targ  <= TARG_HOUR;
                default:    o_targ  <= TARG_SEC;
            endcase
        end
    end

    // ---- 알람 On/Off (수업과 동일, 토글) ----
    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn)         o_alarm_en  <= 1'b0;
        else if(key_alarm)  o_alarm_en  <= ~o_alarm_en;
    end

    // ---- 1초 tick ----
    reg [$clog2(SEC_FREQDIV)-1:0] sec_cnt;
    assign  o_tick_1hz = (sec_cnt == SEC_FREQDIV - 1);
    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn)         sec_cnt <= 0;
        else if(o_tick_1hz) sec_cnt <= 0;
        else                sec_cnt <= sec_cnt + 1;
    end
endmodule
