// ==================================================
//  * Filename      : tb_alarm_timer.v
//  * Description   : top 전체에서 알람 + 타이머 동작 확인 (보드 없이)
//  실행 (sim 폴더에서):
//    iverilog -g2012 -o tb ../src/*.v ../src/class/*.v tb_alarm_timer.v && vvp tb
//  tb_top 과 같이 defparam 으로 분주값을 작게 바꿨습니다.
//    1초 = 1000 클럭, 디바운스 샘플 = 10 클럭, 깜빡임 토글 = 200 클럭
//    알람 자동 꺼짐 = 20초, 타이머 종료음 = 5초
// ==================================================
`timescale 1ns/1ps
module tb_alarm_timer;
    reg         clk = 1'b0;
    reg         rstn = 1'b0;
    reg  [7:0]  sw = 8'hFF;             // 평소 1, 누르면 0 (pull-up)
    wire [5:0]  seg_enb;
    wire [7:0]  seg;
    wire        buzzer;

    top dut(.o_seg_enb(seg_enb), .o_seg(seg), .o_buzzer(buzzer), .i_sw(sw), .i_clk(clk), .i_rstn(rstn));
    defparam dut.u_ctrl.DEB_FREQDIV         = 10;
    defparam dut.u_ctrl.SEC_FREQDIV         = 1000;
    defparam dut.u_blink.FREQDIV            = 200;
    defparam dut.u_ssegdisp.FREQDIV         = 4;
    defparam dut.u_ring.ALARM_RING_SEC      = 20;
    defparam dut.u_ring.TIMER_RING_SEC      = 5;

    always #5 clk = ~clk;

    localparam SW_MODE = 0, SW_TARG = 1, SW_INC = 2, SW_ALARM = 3, SW_DEC = 4, SW_START = 5, SW_STOP = 6;

    integer errors = 0;
    task press(input integer k);        // 버튼 k 를 50클럭 눌렀다 떼기
        begin
            sw[k] = 1'b0; repeat(50)  @(posedge clk);
            sw[k] = 1'b1; repeat(100) @(posedge clk);
        end
    endtask
    task press_n(input integer k, input integer n);
        integer j;
        begin for (j = 0; j < n; j = j + 1) press(k); end
    endtask
    task go_mode(input [1:0] m);        // 원하는 모드가 될 때까지 sw[0]
        begin while (dut.mode !== m) press(SW_MODE); end
    endtask
    task chk(input cond, input [8*120-1:0] msg);
        begin
            if (cond) $display("ok   %0s", msg);
            else begin $display("FAIL %0s", msg); errors = errors + 1; end
        end
    endtask
    task wait_until_ring(input integer max_clk, output integer waited);
        begin
            waited = 0;
            while (dut.buzzer_enb !== 1'b0 && waited < max_clk) begin
                @(posedge clk); waited = waited + 1;
            end
        end
    endtask

    integer i, n, tog, blank;
    reg     pb;
    initial begin
        // 수업 debouncer 의 n1/n2 는 리셋이 없어서 처음엔 X -> 몇 클럭 돌린 뒤 다시 리셋
        repeat(5) @(posedge clk); rstn = 1;
        repeat(100) @(posedge clk); rstn = 0;
        repeat(5) @(posedge clk); rstn = 1;
        repeat(10) @(posedge clk);

        // ---------------- 1) 기본값 ----------------
        chk(dut.alarm_hour == 7 && dut.alarm_min == 0 && dut.alarm_sec == 0, "[1] alarm default 07:00:00");
        chk(dut.timer_hour == 0 && dut.timer_min == 3 && dut.timer_sec == 0, "[1] timer default 00:03:00");
        chk(dut.alarm_en == 1'b0 && buzzer == 1'b0, "[1] alarm off, buzzer silent");

        // ---------------- 2) 알람 설정: 증가/감소 ----------------
        go_mode(2'b10);
        press(SW_TARG);                                 // 분
        press(SW_DEC);
        chk(dut.alarm_hour == 7 && dut.alarm_min == 59, "[2] alarm min dec 00 -> 59");
        press(SW_INC);
        chk(dut.alarm_hour == 7 && dut.alarm_min == 0,  "[2] alarm min inc 59 -> 00");
        press(SW_TARG);                                 // 시
        press(SW_DEC); press(SW_INC);
        chk(dut.alarm_hour == 7, "[2] alarm hour dec/inc -> 07");
        chk(dut.clock_hour == 0, "[2] clock not changed by alarm setting");

        // ---------------- 3) 07:00:00 알람 ----------------
        press(SW_ALARM);
        chk(dut.alarm_en == 1'b1 && dut.u_ssegdisp.i_dp0 == 1'b1, "[3] sw[3] alarm ON, dp0 lit");
        // 시계를 06:59:57 로 설정
        go_mode(2'b01);                                 // CLOCK_SET, 대상 = 초
        while (dut.clock_sec != 57) press(SW_DEC);
        press(SW_TARG); press(SW_DEC);                  // 분 0 -> 59
        press(SW_TARG); press_n(SW_INC, 6);             // 시 0 -> 6
        chk(dut.clock_hour == 6 && dut.clock_min == 59 && dut.clock_sec == 57, "[3] clock set to 06:59:57");
        go_mode(2'b00);                                 // 일반 모드 (시계 다시 흐름)
        wait_until_ring(5000, n);
        chk(dut.alarm_ring && dut.clock_hour == 7 && dut.clock_min == 0 && dut.clock_sec == 0,
            "[3] alarm rings at 07:00:00");
        repeat(10) @(posedge clk);
        chk(dut.song == 1'b0 && dut.u_buzzer.cnt == 7'd0, "[3] alarm melody starts from first note");
        tog = 0; pb = buzzer;
        for (i = 0; i < 45000; i = i + 1) begin @(posedge clk); if (buzzer !== pb) tog = tog + 1; pb = buzzer; end
        chk(tog > 0, "[3] o_buzzer toggles while ringing");
        press(SW_STOP);
        chk(!dut.alarm_ring && dut.buzzer_enb && buzzer == 1'b0, "[3] sw[6] stops alarm");
        chk(dut.alarm_en == 1'b1, "[3] alarm stays ON after stop (next day)");

        // ---------------- 4) 알람 Off 면 안 울림 ----------------
        press(SW_ALARM);
        go_mode(2'b10); press_n(SW_TARG, 1);            // 알람 분 -> 현재 시계 분 + 1
        while (dut.alarm_min != dut.clock_min + 1) press(SW_INC);
        go_mode(2'b00);
        wait_until_ring(62000, n);
        chk(dut.buzzer_enb == 1'b1, "[4] alarm OFF -> no ring at alarm time");

        // ---------------- 5) 타이머 설정 + 동작 ----------------
        go_mode(2'b11);                                 // TIMER, 대상 = 초
        chk(dut.u_blink.i_en == 1'b1, "[5] timer setting: digits blink");
        press(SW_TARG); press_n(SW_DEC, 3);             // 분 3 -> 0
        press(SW_TARG); press(SW_TARG);                 // 시 -> 초
        press_n(SW_INC, 3);                             // 초 0 -> 3
        chk(dut.timer_hour == 0 && dut.timer_min == 0 && dut.timer_sec == 3, "[5] timer set 00:00:03 (dec min, inc sec)");
        press(SW_START);
        chk(dut.timer_state == 2'd1, "[5] sw[5] -> timer RUN");
        chk(dut.u_blink.i_en == 1'b0, "[5] no blink while counting down");
        press(SW_DEC);
        chk(dut.u_timer.set_sec == 3, "[5] dec ignored while running");
        wait_until_ring(5000, n);
        chk(dut.timer_ring && dut.timer_hour == 0 && dut.timer_min == 0 && dut.timer_sec == 0,
            "[5] 00:00:00 -> timer ring");
        chk(dut.song == 1'b1, "[5] timer uses beep pattern (song 1)");
        repeat(6000) @(posedge clk);
        chk(!dut.timer_ring && dut.timer_state == 2'd0 && dut.timer_sec == 3, "[5] auto off -> back to setting 00:00:03");

        // ---------------- 6) 카운트다운 확인 (03:00 -> 02:59) ----------------
        press(SW_TARG); press_n(SW_INC, 3);             // 분 0 -> 3
        press(SW_TARG); press(SW_TARG);                 // 초
        press_n(SW_DEC, 3);                             // 초 3 -> 0  => 00:03:00
        chk(dut.timer_min == 3 && dut.timer_sec == 0, "[6] timer set back to 00:03:00");
        press(SW_START);
        n = 0;
        while (dut.timer_sec == 0 && n < 2000) begin @(posedge clk); n = n + 1; end
        repeat(3) @(posedge clk);
        chk(dut.timer_min == 2 && dut.timer_sec == 59, "[6] 03:00 -> 02:59 (borrow)");

        // ---------------- 7) 일시정지 / 재시작 / 리셋 ----------------
        press(SW_START);
        chk(dut.timer_state == 2'd2, "[7] sw[5] again -> PAUSE");
        i = dut.timer_sec;
        repeat(2500) @(posedge clk);
        chk(dut.timer_sec == i, "[7] value frozen while paused");
        press(SW_START);
        repeat(1200) @(posedge clk);
        chk(dut.timer_state == 2'd1 && dut.timer_sec < i, "[7] resume counts down again");
        press(SW_STOP);
        chk(dut.timer_state == 2'd0 && dut.timer_min == 3 && dut.timer_sec == 0, "[7] sw[6] -> reset to 00:03:00");

        // ---------------- 8) 다른 모드에서도 타이머 계속 + 종료음 ----------------
        press(SW_TARG); press_n(SW_DEC, 3);             // 분 3 -> 0
        press(SW_TARG); press(SW_TARG); press_n(SW_INC, 2);   // 00:00:02
        press(SW_START);
        go_mode(2'b00);
        wait_until_ring(5000, n);
        chk(dut.timer_ring && dut.mode == 2'b00, "[8] timer finishes in CLOCK mode too");
        press(SW_STOP);
        chk(!dut.timer_ring && dut.buzzer_enb, "[8] sw[6] stops timer ring");
        repeat(5) @(posedge clk);
        chk(dut.timer_state == 2'd0, "[8] timer back to setting after stop");

        // ---------------- 9) 00:00:00 이면 시작 안 함 ----------------
        go_mode(2'b11);
        press_n(SW_DEC, 2);                             // 초 2 -> 0 => 00:00:00
        press(SW_START);
        chk(dut.timer_state == 2'd0 && dut.buzzer_enb, "[9] 00:00:00 -> start ignored");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
