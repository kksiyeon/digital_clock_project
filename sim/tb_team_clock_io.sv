`timescale 1ns/1ps
module tb_team_clock_io;
    reg clk = 0, rstn = 1, ir_n = 1, psd_near = 0;
    wire lcd_rs, lcd_rw, lcd_e;
    wire [7:0] lcd_data;
    always #5000 clk = ~clk; // 100 kHz: NEC와 LCD의 물리 시간은 동일하게 유지

    top #(.IO_CLK_HZ(100000), .PSD_STABLE_CYCLES(8),
          .IR_FILTER_ADDRESS(1), .IR_ADDRESS(8'h12)) dut (
        .i_clk(clk), .i_rstn(rstn), .i_sw(8'hFF),
        .i_ir_n(ir_n), .i_adc_dout(1'b0),
        .o_lcd_rs(lcd_rs), .o_lcd_rw(lcd_rw), .o_lcd_e(lcd_e), .o_lcd_data(lcd_data)
    );
    defparam dut.u_ctrl.DEB_FREQDIV = 10;
    // ADC 경로는 tb_psd_adc 에서 따로 확인. 여기서는 '가까움' 레벨을 직접 넣음
    initial force dut.psd_near = psd_near;

    task send_frame(input [7:0] addr, inverse_addr, cmd, inverse_cmd);
        reg [31:0] payload;
        integer n;
        begin
            payload = {inverse_cmd, cmd, inverse_addr, addr};
            ir_n = 0; #9000000; ir_n = 1; #4500000;
            for (n = 0; n < 32; n = n+1) begin
                ir_n = 0; #560000; ir_n = 1;
                if (payload[n]) #1690000; else #560000;
            end
            ir_n = 0; #560000; ir_n = 1; #10000000;
        end
    endtask

    task send_nec(input [7:0] addr, cmd, inverse_cmd);
        send_frame(addr, ~addr, cmd, inverse_cmd);
    endtask

    reg [127:0] lcd_line1 = 0, lcd_line2 = 0;
    reg [6:0] lcd_addr = 0;
    localparam [63:0] LCD_INIT = 64'h303030380801060C;
    integer lcd_init_writes = 0;
    time lcd_last_write;
    always @(negedge lcd_e) if (rstn) begin
        if (lcd_rw !== 0) $fatal(1, "LCD must stay in write mode");
        if (lcd_init_writes < 8) begin
            if (lcd_rs !== 0 || lcd_data !== LCD_INIT[63-8*lcd_init_writes -: 8])
                $fatal(1, "Wrong LCD initialization command %0d", lcd_init_writes);
            case (lcd_init_writes)
                1: if ($time - lcd_last_write <= 4100000) $fatal(1, "LCD first wake wait <= 4.1 ms");
                2: if ($time - lcd_last_write <= 100000) $fatal(1, "LCD second wake wait <= 100 us");
                6: if ($time - lcd_last_write < 1520000) $fatal(1, "LCD clear wait < 1.52 ms");
                default: ;
            endcase
            lcd_init_writes = lcd_init_writes + 1;
            lcd_last_write = $time;
        end
        if (!lcd_rs) begin
            if (lcd_data[7]) lcd_addr = lcd_data[6:0];
        end else begin
            if (lcd_addr < 16) lcd_line1[127-8*lcd_addr -: 8] = lcd_data;
            else if (lcd_addr >= 64 && lcd_addr < 80)
                lcd_line2[127-8*(lcd_addr-64) -: 8] = lcd_data;
            lcd_addr = lcd_addr + 1'b1;
        end
    end

    task start_test_ring;
        begin
            @(negedge clk); force dut.timer_done = 1'b1;
            @(negedge clk); release dut.timer_done;
            if (dut.timer_ring !== 1) $fatal(1, "Timer ring did not start");
        end
    endtask

    task timer_tick;
        begin
            @(negedge clk); force dut.tick_1hz = 1'b1;
            @(negedge clk); release dut.tick_1hz;
            repeat (5) @(negedge clk); // borrow and completion propagate through the counters
        end
    endtask

    initial begin
        #1000; rstn = 0; #100000; rstn = 1;
        #70000000;
        if (lcd_line1 !== "NORMAL          " || lcd_line2 !== "AL 07:00:00 OFF ")
            $fatal(1, "Unexpected initial LCD: %s / %s", lcd_line1, lcd_line2);
        send_nec(8'h13, 8'h45, ~8'h45); // 주소 불일치
        send_nec(8'h12, 8'h45, 8'h45);  // 명령 반전 바이트 오류
        send_frame(8'h12, 8'h12, 8'h45, ~8'h45); // 주소 반전 바이트 오류
        send_nec(8'h12, 8'h00, ~8'h00); // 매핑되지 않은 명령
        if (dut.mode !== 0) $fatal(1, "Invalid remote frame was accepted");
        send_nec(8'h12, 8'h45, ~8'h45);
        if (dut.mode !== 1 || lcd_line1 !== "CLOCK SET       ") $fatal(1, "Clock mode");
        ir_n = 0; #9000000; ir_n = 1; #2250000;
        ir_n = 0; #560000; ir_n = 1; #10000000;
        if (dut.mode !== 1) $fatal(1, "NEC repeat changed mode");
        send_nec(8'h12, 8'h45, ~8'h45);
        send_nec(8'h12, 8'h46, ~8'h46);
        send_nec(8'h12, 8'h18, ~8'h18);
        send_nec(8'h12, 8'h47, ~8'h47);
        if (dut.targ !== 1 || lcd_line1 !== "ALARM SET       " || lcd_line2 !== "AL 07:01:00 ON  ")
            $fatal(1, "Remote field/inc/alarm or LCD status");
        send_nec(8'h12, 8'h52, ~8'h52);
        if (lcd_line2 !== "AL 07:00:00 ON  ") $fatal(1, "Remote decrement");
        send_nec(8'h12, 8'h45, ~8'h45);
        send_nec(8'h12, 8'h40, ~8'h40);
        if (dut.timer_state !== 1 || lcd_line1 !== "TIMER           ") $fatal(1, "Timer start");
        send_nec(8'h12, 8'h40, ~8'h40);
        if (dut.timer_state !== 2) $fatal(1, "Timer pause");
        send_nec(8'h12, 8'h40, ~8'h40);
        if (dut.timer_state !== 1) $fatal(1, "Timer resume");
        send_nec(8'h12, 8'h44, ~8'h44);
        if (dut.timer_state !== 0) $fatal(1, "Timer reset via remote Stop");

        send_nec(8'h12, 8'h40, ~8'h40);
        @(negedge clk); psd_near = 1; repeat (16) @(negedge clk);
        if (dut.timer_state !== 1) $fatal(1, "PSD reset a running timer");
        start_test_ring();
        repeat (16) @(negedge clk);
        if (dut.timer_ring !== 1) $fatal(1, "Already-near PSD muted a new event");
        psd_near = 0; repeat (16) @(negedge clk);
        psd_near = 1; repeat (3) @(negedge clk);
        psd_near = 0; repeat (16) @(negedge clk);
        if (dut.timer_ring !== 1) $fatal(1, "Short PSD pulse was accepted");
        psd_near = 1; repeat (16) @(negedge clk);
        if (dut.timer_ring !== 0 || dut.timer_state !== 1 || dut.alarm_en !== 1)
            $fatal(1, "PSD must mute without resetting timer or alarm enable");
        start_test_ring();
        send_nec(8'h12, 8'h44, ~8'h44);
        if (dut.timer_ring !== 0 || dut.timer_state !== 1) $fatal(1, "Remote mute");

        // 기존 3분 타이머를 실제로 끝낸 뒤 PSD로 울림만 끈다.
        send_nec(8'h12, 8'h45, ~8'h45);
        if (dut.mode !== 0 || lcd_line1 !== "NORMAL          ") $fatal(1, "Mode wrap");
        @(negedge clk); psd_near = 0; repeat (16) @(negedge clk);
        repeat (180) timer_tick();
        if (dut.timer_state !== 3 || dut.timer_ring !== 1) $fatal(1, "Real timer completion");
        psd_near = 1; repeat (16) @(negedge clk);
        if (dut.timer_state !== 0 || dut.timer_ring !== 0 || dut.timer_min !== 3)
            $fatal(1, "PSD did not silence completed timer and preserve its preset");

        // 알람 시각이 일치하는 동안 PSD로 끈 뒤 다시 울리지 않아야 한다.
        psd_near = 0; repeat (16) @(negedge clk);
        force dut.clock_hour = 6'd7;
        force dut.clock_min = 6'd0;
        force dut.clock_sec = 6'd0;
        repeat (4) @(negedge clk);
        if (dut.alarm_ring !== 1) $fatal(1, "Alarm did not start");
        psd_near = 1; repeat (16) @(negedge clk);
        if (dut.alarm_ring !== 0 || dut.alarm_en !== 1) $fatal(1, "PSD must keep alarm enabled");
        release dut.clock_hour;
        release dut.clock_min;
        release dut.clock_sec;

        // 알람을 PSD로 끄는 클럭에 도착한 새 타이머 종료 이벤트는 유실하지 않는다.
        psd_near = 0; repeat (16) @(negedge clk);
        force dut.clock_hour = 6'd7;
        force dut.clock_min = 6'd0;
        force dut.clock_sec = 6'd0;
        repeat (4) @(negedge clk);
        if (dut.alarm_ring !== 1) $fatal(1, "Alarm did not rearm");
        psd_near = 1;
        @(posedge dut.psd_mute);
        @(negedge clk); force dut.timer_done = 1'b1;
        @(negedge clk); release dut.timer_done;
        if (dut.alarm_ring !== 0 || dut.timer_ring !== 1) $fatal(1, "Concurrent timer event lost");
        release dut.clock_hour;
        release dut.clock_min;
        release dut.clock_sec;
        $display("PASS: team clock IR/LCD/PSD integration");
        $finish;
    end
    initial #4000000000 $fatal(1, "Test timed out");
endmodule
