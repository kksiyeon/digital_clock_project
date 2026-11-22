// ==================================================
//  * Filename      : arbiter.v
//  * Description   : 모드에 따라 시계/알람/타이머 값 선택 -> 6자리로 분리
//
//  ※ 수업 9주차 arbiter 에 있던 알람 비교(o_buzzer_enb) 부분은 알람 담당 모듈 쪽이라
//    여기서는 뺐습니다. 알람 모듈 쪽에 두거나 이 파일에 다시 붙이면 됩니다.
// ==================================================
module  arbiter
(
    output      [3:0]   o_num0,
    output      [3:0]   o_num1,
    output      [3:0]   o_num2,
    output      [3:0]   o_num3,
    output      [3:0]   o_num4,
    output      [3:0]   o_num5,
    input       [1:0]   i_mode,
    input       [5:0]   i_clock_hour,
    input       [5:0]   i_clock_min,
    input       [5:0]   i_clock_sec,
    input       [5:0]   i_alarm_hour,
    input       [5:0]   i_alarm_min,
    input       [5:0]   i_alarm_sec,
    input       [5:0]   i_timer_hour,
    input       [5:0]   i_timer_min,
    input       [5:0]   i_timer_sec
);
    localparam  MODE_CLOCK_OPR  = 2'b00;
    localparam  MODE_CLOCK_SET  = 2'b01;
    localparam  MODE_ALARM_SET  = 2'b10;
    localparam  MODE_TIMER      = 2'b11;

    reg     [5:0]   hour, min, sec;
    always @(*) begin
        case(i_mode)
            MODE_ALARM_SET: begin hour = i_alarm_hour; min = i_alarm_min; sec = i_alarm_sec; end
            MODE_TIMER:     begin hour = i_timer_hour; min = i_timer_min; sec = i_timer_sec; end
            default:        begin hour = i_clock_hour; min = i_clock_min; sec = i_clock_sec; end
        endcase
    end

    assign  o_num1 = sec  / 10;
    assign  o_num0 = sec  % 10;
    assign  o_num3 = min  / 10;
    assign  o_num2 = min  % 10;
    assign  o_num5 = hour / 10;
    assign  o_num4 = hour % 10;
endmodule
