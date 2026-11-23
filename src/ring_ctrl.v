// ==================================================
//  * Filename      : ring_ctrl.v
//  * Description   : 알람 / 타이머 울림 제어    [신규 - 수업 9주차 arbiter 의 알람 비교 부분을 분리]
//
//  팀원 arbiter.v 에서 빼 둔 "알람 비교(o_buzzer_enb)" 부분을 여기로 옮기고 타이머 종료음을 더함
//   - 알람 : 알람 On(ctrl 의 o_alarm_en) 이고 현재 시각 == 알람 시각이면 울림 시작
//            시계 설정 중(i_clock_setting=1)에는 울리지 않음, 같은 1초 안에서 다시 시작하지 않음
//   - 타이머: timer 의 o_done 펄스가 오면 종료음 시작
//   - 끄기 : i_stop(정지 버튼), 알람 Off, 또는 ALARM_RING_SEC / TIMER_RING_SEC 초 지나면 자동
//   - o_buzzer_enb : active-low (수업 9주차 buzzer 와 같음)
//   - o_song       : 0 = 알람 노래, 1 = 타이머 비프 (둘 다 울리면 알람 노래)
// ==================================================
module  ring_ctrl
#(
    parameter   ALARM_RING_SEC = 60,
    parameter   TIMER_RING_SEC = 10
)
(
    output              o_buzzer_enb,
    output              o_song,
    output reg          o_alarm_ring,
    output reg          o_timer_ring,
    input               i_alarm_en,
    input               i_clock_setting,
    input       [5:0]   i_clock_hour,
    input       [5:0]   i_clock_min,
    input       [5:0]   i_clock_sec,
    input       [5:0]   i_alarm_hour,
    input       [5:0]   i_alarm_min,
    input       [5:0]   i_alarm_sec,
    input               i_timer_done,
    input               i_stop,
    input               i_tick_1s,
    input               i_clk,
    input               i_rstn
);
    wire            time_match = (i_clock_hour == i_alarm_hour) &&
                                 (i_clock_min  == i_alarm_min ) &&
                                 (i_clock_sec  == i_alarm_sec );
    reg             alarm_triggered;
    reg     [7:0]   ring_sec;

    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            o_alarm_ring    <= 1'b0;
            o_timer_ring    <= 1'b0;
            alarm_triggered <= 1'b0;
            ring_sec        <= 8'd0;
        end else begin
            if(i_alarm_en && !i_clock_setting && time_match && !alarm_triggered) begin
                o_alarm_ring    <= 1'b1;
                alarm_triggered <= 1'b1;
                ring_sec        <= 8'd0;
            end
            if(!time_match) alarm_triggered <= 1'b0;

            if(i_timer_done) begin
                o_timer_ring    <= 1'b1;
                ring_sec        <= 8'd0;
            end

            if(o_alarm_ring || o_timer_ring) begin
                if(i_stop) begin
                    o_alarm_ring    <= 1'b0;
                    o_timer_ring    <= 1'b0;
                end else begin
                    if(!i_alarm_en) o_alarm_ring <= 1'b0;
                    if(i_tick_1s) begin
                        ring_sec <= ring_sec + 8'd1;
                        if(o_alarm_ring && ring_sec >= ALARM_RING_SEC - 1) o_alarm_ring <= 1'b0;
                        if(o_timer_ring && ring_sec >= TIMER_RING_SEC - 1) o_timer_ring <= 1'b0;
                    end
                end
            end
        end
    end

    assign  o_buzzer_enb = ~(o_alarm_ring | o_timer_ring);
    assign  o_song       = o_timer_ring & ~o_alarm_ring;
endmodule
