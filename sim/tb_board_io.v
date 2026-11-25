// ==================================================
//  * Filename      : tb_board_io.v
//  * Description   : 보드 연결 부분 확인
//    1) psd_adc 가 ADC128S102 프레임(SCLK 16번, 채널 주소, 12비트 값)을 맞게 주고받는지
//    2) 임계값 + 히스테리시스로 '가까움' 판단
//    3) top 전체: 알람이 울릴 때 ADC 값이 커지면(손을 가까이) 울림이 꺼지고 알람 ON 은 유지
//    4) 보드 기본 설정(SW0_SHARED_WITH_IR=0): IR 이 따로 있어도 모드 버튼 = sw[0]
//    5) 수업 리모콘(LY) 코드표 값 그대로 보낸 프레임으로 버튼 매핑 확인, sw[7] 리모콘 확인 화면
//  실행 (저장소 루트):
//    iverilog -g2012 -s tb_board_io -o /tmp/tb_board_io src/*.v src/class/*.v sim/tb_board_io.v
//    vvp /tmp/tb_board_io
// ==================================================
`timescale 1ns/1ps
module tb_board_io;
    reg         clk = 1'b0, rstn = 1'b0;
    reg  [7:0]  sw = 8'hFF;
    wire [5:0]  seg_enb;
    wire [7:0]  seg;
    wire        buzzer, adc_csn, adc_sclk, adc_din;
    wire        lcd_rs, lcd_rw, lcd_e;
    wire [7:0]  lcd_data;
    reg         adc_dout = 1'b0;
    reg         ir_n = 1'b1;

    top #(.PSD_ADC_CH(3'd5), .PSD_STABLE_CYCLES(100)) dut(
        .o_seg_enb(seg_enb), .o_seg(seg), .o_buzzer(buzzer),
        .i_sw(sw), .i_clk(clk), .i_rstn(rstn),
        .i_ir_n(ir_n),
        .o_adc_csn(adc_csn), .o_adc_sclk(adc_sclk), .o_adc_din(adc_din), .i_adc_dout(adc_dout),
        .o_lcd_rs(lcd_rs), .o_lcd_rw(lcd_rw), .o_lcd_e(lcd_e), .o_lcd_data(lcd_data)
    );
    defparam dut.u_ctrl.DEB_FREQDIV = 10;
    defparam dut.u_ctrl.SEC_FREQDIV = 1000;

    always #10 clk = ~clk;      // 50MHz

    // ---- ADC128S102 동작 모델 ----
    //  CS 하강 후 SCLK 하강 n번째(1~16)에 비트 n 출력: 1~4 = 0, 5~16 = DB11..DB0
    //  SCLK 상승 3~5번째에 DIN 을 읽어 다음 변환 채널로 사용
    reg  [11:0] adc_val [0:7];
    reg  [2:0]  adc_ch_next = 3'd0, adc_ch_cur = 3'd0, adc_addr_rx = 3'd0;
    integer     nfall = 0, nrise = 0, frames = 0, bad_frames = 0;
    always @(negedge adc_csn) begin
        nfall = 0; nrise = 0; adc_ch_cur = adc_ch_next;
    end
    always @(posedge adc_csn) begin
        frames = frames + 1;
        if (nrise != 16 || nfall != 16) bad_frames = bad_frames + 1;
        adc_ch_next = adc_addr_rx;
    end
    always @(negedge adc_sclk) if (!adc_csn) begin
        nfall = nfall + 1;
        adc_dout <= #5 (nfall <= 4) ? 1'b0 : adc_val[adc_ch_cur][16 - nfall];
    end
    always @(posedge adc_sclk) if (!adc_csn) begin
        nrise = nrise + 1;
        if (nrise >= 3 && nrise <= 5) adc_addr_rx[5 - nrise] = adc_din;
    end

    integer errors = 0, i;
    task chk(input cond, input [8*100-1:0] msg);
        begin
            if (cond) $display("ok   %0s", msg);
            else begin $display("FAIL %0s", msg); errors = errors + 1; end
        end
    endtask
    task wait_frames(input integer n);
        integer f0;
        begin f0 = frames; wait (frames >= f0 + n); repeat (20) @(posedge clk); end
    endtask
    task nec(input [7:0] c);            // 실제 50MHz 타이밍의 NEC 프레임 (주소 0x00)
        reg [31:0] p; integer n;
        begin
            p = {~c, c, 8'hFF, 8'h00};
            ir_n = 0; #9000000; ir_n = 1; #4500000;
            for (n = 0; n < 32; n = n + 1) begin
                ir_n = 0; #560000; ir_n = 1;
                if (p[n]) #1690000; else #560000;
            end
            ir_n = 0; #560000; ir_n = 1; #2000000;
        end
    endtask
    task nec_tbl(input [31:0] v);       // 수업 코드표 값 그대로: v[31] 부터 받은 순서대로 전송
        integer n;
        begin
            ir_n = 0; #9000000; ir_n = 1; #4500000;
            for (n = 31; n >= 0; n = n - 1) begin
                ir_n = 0; #560000; ir_n = 1;
                if (v[n]) #1690000; else #560000;
            end
            ir_n = 0; #560000; ir_n = 1; #2000000;
        end
    endtask
    task nec_ext(input [7:0] c);        // 확장 NEC: 주소 2바이트가 반전 관계가 아님 (0x7F80)
        reg [31:0] p; integer n;
        begin
            p = {~c, c, 8'h7F, 8'h80};
            ir_n = 0; #9000000; ir_n = 1; #4500000;
            for (n = 0; n < 32; n = n + 1) begin
                ir_n = 0; #560000; ir_n = 1;
                if (p[n]) #1690000; else #560000;
            end
            ir_n = 0; #560000; ir_n = 1; #2000000;
        end
    endtask
    task press(input integer k);
        begin
            sw[k] = 1'b0; repeat (50) @(posedge clk);
            sw[k] = 1'b1; repeat (100) @(posedge clk);
        end
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1) adc_val[i] = 12'h111 * i;
        adc_val[5] = 12'd300;                   // 멀리 있음
        repeat (5) @(posedge clk); rstn = 1;
        repeat (100) @(posedge clk); rstn = 0;
        repeat (5) @(posedge clk); rstn = 1;
        bad_frames = 0;                         // 첫 리셋 때 중간에 끊긴 프레임은 제외

        // 1) SPI 프레임과 채널 주소
        wait_frames(3);
        chk(bad_frames == 0, "ADC frame = SCLK 16 clocks");
        chk(adc_addr_rx == 3'd5, "channel address 5 sent on DIN");
        chk(dut.psd_data == 12'd300, "12-bit value read from channel 5");
        adc_val[5] = 12'hA5C; wait_frames(2);
        chk(dut.psd_data == 12'hA5C, "all 12 bits incl. LSB (0xA5C)");

        // 2) 히스테리시스 (TH_ON 2000 / TH_OFF 1600)
        adc_val[5] = 12'd1500; wait_frames(2);
        chk(dut.psd_near == 1'b0, "1500 -> far");
        adc_val[5] = 12'd1999; wait_frames(2);
        chk(dut.psd_near == 1'b0, "1999 -> still far (below TH_ON)");
        adc_val[5] = 12'd2100; wait_frames(2);
        chk(dut.psd_near == 1'b1, "2100 -> near");
        adc_val[5] = 12'd1700; wait_frames(2);
        chk(dut.psd_near == 1'b1, "1700 -> still near (above TH_OFF)");
        adc_val[5] = 12'd1500; wait_frames(2);
        chk(dut.psd_near == 1'b0, "1500 -> far again");

        // 3) 알람 울림 중 손을 가까이 -> 울림만 꺼짐
        press(3);                                   // 알람 ON
        chk(dut.alarm_en == 1'b1, "sw[3] alarm ON");
        force dut.clock_hour = 6'd7; force dut.clock_min = 6'd0; force dut.clock_sec = 6'd0;
        repeat (10) @(posedge clk);
        chk(dut.alarm_ring == 1'b1, "alarm rings at 07:00:00");
        adc_val[5] = 12'd2500; wait_frames(3); repeat (300) @(posedge clk);
        chk(dut.alarm_ring == 1'b0, "hand near (ADC 2500) -> alarm ring stops");
        chk(dut.alarm_en == 1'b1, "alarm stays ON after PSD mute");
        release dut.clock_hour; release dut.clock_min; release dut.clock_sec;
        adc_val[5] = 12'd300; wait_frames(3);

        // 4) 보드 기본 설정: 모드 = sw[0], sw[7] 은 사용 안 함
        chk(dut.mode == 2'd0, "mode CLOCK_OPR");
        press(7);
        chk(dut.mode == 2'd0, "sw[7] does not change mode");
        press(7);                                   // sw[7] 은 리모콘 코드 화면 토글 -> 다시 끔
        press(0);
        chk(dut.mode == 2'd1, "sw[0] -> CLOCK_SET");
        press(1);
        chk(dut.targ == 2'd1, "sw[1] still selects field");

        // 5) 수업 리모콘 기본 코드
        press(0); press(0); press(0);
        chk(dut.mode == 2'd0, "back to CLOCK_OPR");
        nec_tbl(32'h00FD40BF); chk(dut.mode == 2'd1, "MENU(0xFD40BF) -> mode");
        nec_tbl(32'h00FD50AF); chk(dut.targ == 2'd1, "RIGHT(0xFD50AF) -> field MIN");
        nec_tbl(32'h00FD10EF); chk(dut.targ == 2'd2, "LEFT(0xFD10EF) -> field HOUR");
        nec_tbl(32'h00FDA05F); chk(dut.clock_hour == 6'd1, "UP(0xFDA05F) -> hour +1");
        nec_tbl(32'h00FD20DF); chk(dut.clock_hour == 6'd2, "PLUS(0xFD20DF) -> hour +1");
        nec_tbl(32'h00FDB04F); chk(dut.clock_hour == 6'd1, "DOWN(0xFDB04F) -> hour -1");
        nec_tbl(32'h00FD30CF); chk(dut.clock_hour == 6'd0, "MINUS(0xFD30CF) -> hour -1");
        nec_tbl(32'h00FD00FF); chk(dut.alarm_en == 1'b0, "POWER(0xFD00FF) -> alarm toggle (ON->OFF)");
        nec_tbl(32'h00FD40BF); nec_tbl(32'h00FD40BF);
        chk(dut.mode == 2'd3, "MENU x2 -> TIMER");
        nec_tbl(32'h00FD906F); chk(dut.timer_state == 2'd1, "OK(0xFD906F) -> timer start");
        nec_tbl(32'h00FD609F); chk(dut.timer_state == 2'd0, "BACK(0xFD609F) -> timer reset");
        nec_tbl(32'h00FD48B7); chk(dut.mode == 2'd3 && dut.timer_state == 2'd0, "unmapped '3'(0xFD48B7) does nothing");
        // 코드 확인 화면: sw[7] -> 7-seg 에 주소 000, 명령 094 (0x5E)
        press(7);
        chk(dut.ir_dbg == 1'b1, "sw[7] -> IR code view ON");
        chk(dut.ir_edges == 10'd442, "view: IR falling edges counted (34 per frame x 13 frames)");
        chk(dut.dbg_num[5] == 4 && dut.dbg_num[4] == 4 && dut.dbg_num[3] == 2, "view: edge count 442 shown");
        chk(dut.dbg_num[2] == 0 && dut.dbg_num[1] == 1 && dut.dbg_num[0] == 8, "view: command 018 (button 3 = 0x12)");
        nec_tbl(32'h00FD40BF);
        chk(dut.dbg_num[2] == 0 && dut.dbg_num[1] == 0 && dut.dbg_num[0] == 2, "view updates: 002 (MENU)");
        nec_ext(8'h19);
        chk(dut.ir_cmd == 8'h19, "other 16-bit address NEC accepted");
        press(7);
        chk(dut.ir_dbg == 1'b0, "sw[7] again -> normal view");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $fatal(1, "%0d TEST(S) FAILED", errors);
        $finish;
    end
    initial #2000000000 $fatal(1, "timeout");
endmodule
