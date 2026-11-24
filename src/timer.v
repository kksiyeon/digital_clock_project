// ==================================================
//  * Filename      : timer.v
//  * Description   : 카운트다운 타이머            [신규 - clock / alarm 구조 응용]
//
//  - 설정값 : alarm_cnt 3개 재사용 (리셋하면 00:03:00)
//             TIMER 모드이고 '설정 상태(IDLE)'일 때만 증가/감소
//             입력은 팀원 hms_cnt 와 같은 형태 (i_set, i_targ, i_inc, i_dec)
//  - 동작값 : timer_cnt 3개 (초 -> 분 -> 시 로 borrow 연결)
//  - 상태   : IDLE(설정) --시작--> RUN(1초마다 -1) <--시작/정지 버튼--> PAUSE
//             RUN 에서 00:00:00 이 되면 DONE + o_done 1클럭 펄스 (ring_ctrl 이 종료음)
//             DONE 은 종료음이 꺼지면(i_ring 1->0) IDLE 로, 언제든 i_reset 이면 IDLE 로
//  - 모드를 바꿔도 타이머는 뒤에서 계속 돌아감 (끝나면 어느 모드에서든 울림)
// ==================================================
module  timer
(
    output      [5:0]   o_hour,         // 표시값 (IDLE: 설정값, 그 외: 남은 시간)
    output      [5:0]   o_min,
    output      [5:0]   o_sec,
    output reg  [1:0]   o_state,        // 0 IDLE, 1 RUN, 2 PAUSE, 3 DONE
    output reg          o_done,         // 00:00:00 도달 1클럭 펄스
    input               i_set,          // TIMER 모드 (top 에서 mode == MODE_TIMER)
    input       [1:0]   i_targ,         // 2'd0 초, 2'd1 분, 2'd2 시
    input               i_inc,
    input               i_dec,
    input               i_start,        // 시작 / 일시정지 / 다시 시작 (1클럭 펄스)
    input               i_reset,        // 멈추고 설정값으로 (1클럭 펄스)
    input               i_tick,         // 1초 펄스 (ctrl 의 o_tick_1hz)
    input               i_ring,         // 타이머 종료음 울리는 중 (ring_ctrl 의 o_timer_ring)
    input               i_clk,
    input               i_rstn
);
    localparam  T_IDLE      = 2'd0;
    localparam  T_RUN       = 2'd1;
    localparam  T_PAUSE     = 2'd2;
    localparam  T_DONE      = 2'd3;
    localparam  TARG_SEC    = 2'd0;
    localparam  TARG_MIN    = 2'd1;
    localparam  TARG_HOUR   = 2'd2;

    // ---- 설정값 (alarm_cnt 재사용) ----
    wire    [5:0]   set_hour, set_min, set_sec;
    wire            set_en   = i_set & (o_state == T_IDLE);
    wire            sel_sec  = set_en & (i_targ == TARG_SEC );
    wire            sel_min  = set_en & (i_targ == TARG_MIN );
    wire            sel_hour = set_en & (i_targ == TARG_HOUR);

    alarm_cnt #(.MAX(59), .INIT(0)) u_set_sec (
        .o_cnt(set_sec ), .i_inc(sel_sec  & i_inc), .i_dec(sel_sec  & i_dec), .i_clk(i_clk), .i_rstn(i_rstn));
    alarm_cnt #(.MAX(59), .INIT(3)) u_set_min (
        .o_cnt(set_min ), .i_inc(sel_min  & i_inc), .i_dec(sel_min  & i_dec), .i_clk(i_clk), .i_rstn(i_rstn));
    alarm_cnt #(.MAX(23), .INIT(0)) u_set_hour(
        .o_cnt(set_hour), .i_inc(sel_hour & i_inc), .i_dec(sel_hour & i_dec), .i_clk(i_clk), .i_rstn(i_rstn));

    // ---- 동작값 (timer_cnt) ----
    wire    [5:0]   run_hour, run_min, run_sec;
    wire            sec_borrow, min_borrow;
    wire            set_zero = (set_hour == 6'd0) && (set_min == 6'd0) && (set_sec == 6'd0);
    wire            run_zero = (run_hour == 6'd0) && (run_min == 6'd0) && (run_sec == 6'd0);
    wire            load     = (o_state == T_IDLE) && i_start && !set_zero;
    wire            dec      = (o_state == T_RUN)  && i_tick;

    timer_cnt #(.MAX(59)) u_timer_cnt_sec (
        .o_cnt(run_sec ), .o_borrow(sec_borrow), .i_load(load), .i_load_val(set_sec ),
        .i_en(dec       ), .i_clk(i_clk), .i_rstn(i_rstn));
    timer_cnt #(.MAX(59)) u_timer_cnt_min (
        .o_cnt(run_min ), .o_borrow(min_borrow), .i_load(load), .i_load_val(set_min ),
        .i_en(sec_borrow), .i_clk(i_clk), .i_rstn(i_rstn));
    timer_cnt #(.MAX(23)) u_timer_cnt_hour(
        .o_cnt(run_hour), .o_borrow(          ), .i_load(load), .i_load_val(set_hour),
        .i_en(min_borrow), .i_clk(i_clk), .i_rstn(i_rstn));

    // ---- 상태 FSM ----
    reg     ring_d;
    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            o_state <= T_IDLE;
            o_done  <= 1'b0;
            ring_d  <= 1'b0;
        end else begin
            o_done  <= 1'b0;
            ring_d  <= i_ring;
            case(o_state)
                T_IDLE  : if(load)          o_state <= T_RUN;
                T_RUN   : begin
                    if(i_reset)             o_state <= T_IDLE;
                    else if(i_start)        o_state <= T_PAUSE;
                    else if(run_zero && !dec && !sec_borrow && !min_borrow) begin
                        o_state <= T_DONE;              // 00:00:00 도달
                        o_done  <= 1'b1;
                    end
                end
                T_PAUSE : begin
                    if(i_reset)             o_state <= T_IDLE;
                    else if(i_start)        o_state <= T_RUN;
                end
                default : begin             // T_DONE
                    if(i_reset || (ring_d && !i_ring)) o_state <= T_IDLE;
                end
            endcase
        end
    end

    assign  o_hour = (o_state == T_IDLE) ? set_hour : run_hour;
    assign  o_min  = (o_state == T_IDLE) ? set_min  : run_min;
    assign  o_sec  = (o_state == T_IDLE) ? set_sec  : run_sec;
endmodule
