// ==================================================
//  * Filename      : tb_top.v
//  * Description   : top 전체 시뮬레이션 (보드 없이 확인)
//  실행 (sim 폴더에서):
//    iverilog -g2012 -o tb ../src/*.v ../src/class/*.v tb_top.v && vvp tb
//  시뮬레이션 시간을 줄이려고 defparam 으로 분주값을 작게 바꿨습니다.
//    1초 = 1000 클럭, 디바운스 샘플 = 10 클럭, 깜빡임 토글 = 200 클럭
// ==================================================
`timescale 1ns/1ps
module tb_top;
    reg         clk = 1'b0;
    reg         rstn = 1'b0;
    reg  [7:0]  sw = 8'hFF;             // 평소 1, 누르면 0 (pull-up)
    wire [5:0]  seg_enb;
    wire [7:0]  seg;

    top #(.SW0_SHARED_WITH_IR(1'b0)) dut(.o_seg_enb(seg_enb), .o_seg(seg), .i_sw(sw), .i_clk(clk), .i_rstn(rstn),
            .i_ir_n(1'b1), .i_adc_dout(1'b0));
    defparam dut.u_ctrl.DEB_FREQDIV = 10;
    defparam dut.u_ctrl.SEC_FREQDIV = 1000;
    defparam dut.u_blink.FREQDIV    = 200;
    defparam dut.u_ssegdisp.FREQDIV = 4;

    always #5 clk = ~clk;

    integer errors = 0;
    task press(input integer k);        // 버튼 k 를 50클럭 눌렀다 떼기
        begin
            sw[k] = 1'b0; repeat(50)  @(posedge clk);
            sw[k] = 1'b1; repeat(100) @(posedge clk);
        end
    endtask
    task chk_clock(input [5:0] h, input [5:0] m, input [5:0] s, input [8*120-1:0] msg);
        begin
            if (dut.clock_hour !== h || dut.clock_min !== m || dut.clock_sec !== s) begin
                $display("FAIL %0s : clock %0d:%0d:%0d (expect %0d:%0d:%0d)", msg,
                         dut.clock_hour, dut.clock_min, dut.clock_sec, h, m, s);
                errors = errors + 1;
            end else
                $display("ok   %0s : clock %02d:%02d:%02d", msg, dut.clock_hour, dut.clock_min, dut.clock_sec);
        end
    endtask
    task chk(input cond, input [8*120-1:0] msg);
        begin
            if (cond) $display("ok   %0s", msg);
            else begin $display("FAIL %0s", msg); errors = errors + 1; end
        end
    endtask

    integer i, tog_hour, tog_other;
    reg [3:0] p4, p0;
    reg [5:0] h0, m0, s0;
    initial begin
        // 수업 debouncer 의 n1/n2 는 리셋이 없어서 처음엔 X -> 몇 클럭 돌린 뒤 다시 리셋
        repeat(5) @(posedge clk); rstn = 1;
        repeat(100) @(posedge clk); rstn = 0;
        repeat(5) @(posedge clk); rstn = 1;

        // 1) 일반 모드: 시계가 흐름
        repeat(3500) @(posedge clk);
        chk_clock(0, 0, 3, "normal mode, after 3.5s");

        // 2) 시계 설정 모드 진입 -> 멈춤, 대상 = 초
        press(0);
        chk(dut.mode == 2'b01 && dut.targ == 2'd0, "sw[0] -> CLOCK_SET, targ=SEC");
        s0 = dut.clock_sec;
        repeat(2000) @(posedge clk);
        chk(dut.clock_sec == s0, "clock stops while setting");
        // 초 감소: 3 -> 0 -> 59
        press(4); press(4); press(4);
        chk_clock(0, 0, 0, "sec dec x3 (3->0)");
        press(4);
        chk_clock(0, 0, 59, "sec 0 dec -> 59");
        press(2);
        chk_clock(0, 0, 0, "sec 59 inc -> 0 (no carry to min)");
        press(4);
        // 분
        press(1);
        chk(dut.targ == 2'd1, "sw[1] -> targ=MIN");
        press(4);
        chk_clock(0, 59, 59, "min 0 dec -> 59");
        // 시
        press(1);
        chk(dut.targ == 2'd2, "sw[1] -> targ=HOUR");
        press(4);
        chk_clock(23, 59, 59, "hour 0 dec -> 23");
        press(2);
        chk_clock(0, 59, 59, "hour 23 inc -> 0");
        press(4); press(4);
        chk_clock(22, 59, 59, "hour dec x2 -> 22");

        // 3) blink: 시(num4,num5)만 깜빡이고 나머지는 그대로
        tog_hour = 0; tog_other = 0; p4 = dut.disp_num[4]; p0 = dut.disp_num[0];
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);
            if (dut.disp_num[4] !== p4) tog_hour  = tog_hour + 1;
            if (dut.disp_num[0] !== p0) tog_other = tog_other + 1;
            p4 = dut.disp_num[4]; p0 = dut.disp_num[0];
        end
        chk(tog_hour >= 4 && tog_other == 0, "blink: only hour digits blink");
        press(2); // 버튼 누르면 바로 켜짐
        chk(dut.disp_num[4] != 4'd15, "digits visible right after key press (hold)");
        press(4);

        // 4) 알람 설정: 시계와 따로 저장, 대상은 초로 리셋
        press(0);
        chk(dut.mode == 2'b10 && dut.targ == 2'd0, "sw[0] -> ALARM_SET, targ reset to SEC");
        press(4);
        chk(dut.alarm_hour == 7 && dut.alarm_min == 0 && dut.alarm_sec == 59, "alarm sec dec -> 07:00:59 (alarm default 07:00:00, separate from clock)");
        chk(dut.clock_hour == 23 && dut.clock_min == 0, "clock runs again after set (22:59:59 -> 23:00)");

        // 5) 타이머 모드 -> 일반 모드, 시계 다시 흐름 + 깜빡임 없음
        press(0);
        chk(dut.mode == 2'b11, "sw[0] -> TIMER");
        press(0);
        chk(dut.mode == 2'b00, "sw[0] -> CLOCK_OPR");
        h0 = dut.clock_hour; m0 = dut.clock_min; s0 = dut.clock_sec;
        repeat(1500) @(posedge clk);
        chk(dut.clock_hour == 23 && dut.clock_min == 0 && dut.clock_sec > s0, "normal mode: clock keeps running");
        chk(dut.disp_num[4] != 4'd15 && dut.disp_num[0] != 4'd15, "normal mode: no blink");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $fatal(1, "%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
