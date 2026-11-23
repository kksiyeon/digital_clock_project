// ==================================================
//  * Filename      : buzzer.v
//  * Description   : 부저 멜로디 재생                 [9주차 buzzer.v 수정]
//
//  - 9주차: buzzer_nco 하나로 고정 음(1kHz) -> o_out = ~i_enb & buzz_clk
//  - 팀플 : 강의 buzzer 구조(박자 NCO + 악보 + 음 NCO)로 멜로디 재생
//           1) 박자 : buzzer_nco 로 1kHz 를 만들고 상승엣지 = 1ms 틱
//           2) 악보 : buzzer_sheet 의 음표마다 길이(o_len x UNIT_MS)만큼 재생
//                     음 끝 GAP_MS 는 쉼 -> 같은 음이 반복돼도 끊어져 들림
//           3) 음   : buzzer_nco 의 i_freq_div 에 악보의 FREQDIV 를 넣음
//           4) i_enb 가 1->0 (울림 시작) 이 되면 항상 악보 처음(주소 0)부터 시작
// ==================================================
module buzzer #(
    parameter   FREQDIV_1MS = 50000,    // 50MHz / 50000 = 1kHz -> 1ms
    parameter   UNIT_MS     = 250,      // 8분음표 길이 (4분음표 0.5초)
    parameter   GAP_MS      = 30
)(
    output          o_out,
    input           i_enb,              // active-low (9주차와 동일)
    input           i_song,             // 0: 알람 노래, 1: 타이머 비프
    input           i_clk,
    input           i_rstn
);
    // ---- 1) 박자용 1ms 틱 ----
    wire    beat_clk;
    reg     beat_clk_d;
    wire    tick_1ms = beat_clk & ~beat_clk_d;
    buzzer_nco u_buzzer_nco_beat(
        .o_clk          (beat_clk       ),
        .i_freq_div     (FREQDIV_1MS    ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    // ---- 2) 악보 ----
    reg     [6:0]   cnt;                // 악보 주소
    reg     [15:0]  ms;                 // 현재 음표 진행 시간
    wire    [31:0]  note;
    wire    [3:0]   len;
    wire    [15:0]  dur_ms = len * UNIT_MS;
    wire    [6:0]   song_base = i_song ? 7'd64 : 7'd0;
    reg             enb_d;

    buzzer_sheet u_buzzer_sheet(
        .o_note         (note           ),
        .o_len          (len            ),
        .i_cnt          (cnt            )
    );

    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            beat_clk_d  <= 1'b0;
            enb_d       <= 1'b1;
            cnt         <= 7'd0;
            ms          <= 16'd0;
        end else begin
            beat_clk_d  <= beat_clk;
            enb_d       <= i_enb;
            if(i_enb || enb_d) begin
                // 꺼져 있거나 막 울리기 시작한 순간 -> 노래 첫 음표
                cnt     <= i_enb ? 7'd0 : song_base;
                ms      <= 16'd0;
            end else if(tick_1ms) begin
                if(len == 4'd0) begin                       // 곡의 끝 -> 반복
                    cnt <= song_base;
                    ms  <= 16'd0;
                end else if(ms >= dur_ms - 1) begin         // 다음 음표
                    cnt <= cnt + 1'b1;
                    ms  <= 16'd0;
                end else begin
                    ms  <= ms + 1'b1;
                end
            end
        end
    end

    // ---- 3) 음 높이 ----
    wire    buzz;
    buzzer_nco u_buzzer_nco_note(
        .o_clk          (buzz           ),
        .i_freq_div     (note           ),
        .i_clk          (i_clk          ),
        .i_rstn         (i_rstn         )
    );

    wire    sounding = ~i_enb && ~enb_d && (note != 0) && (len != 4'd0) && (ms < dur_ms - GAP_MS);
    assign  o_out = sounding & buzz;
endmodule
