// ==================================================
//  * Filename      : buzzer_sheet.v
//  * Description   : 악보 (음 높이 + 음 길이)        [신규 - 9주차 강의 buzzer_sheet 구조 응용]
//
//  - 9주차 강의 예제: 한 칸 = 같은 박자, 음 이름(FREQDIV)만 저장
//  - 팀플 : 한 칸 = 음표 하나, 음 높이(o_note)와 길이(o_len, 8분음표 단위)를 같이 저장
//           -> 8분/4분/점4분/2분 음표 길이가 그대로 재생됨 ("자연스러운 음 길이")
//           o_len = 0 은 곡의 끝 표시
//  - song 0 (주소 0~)  : 베토벤 "환희의 송가" (퍼블릭 도메인)
//  - song 1 (주소 64~) : 타이머 종료 비프음
// ==================================================
module  buzzer_sheet(
    output reg  [31:0]  o_note,         // FREQDIV (50MHz 기준, 9주차 음계표)
    output reg  [3:0]   o_len,          // 8분음표 단위 (1=8분, 2=4분, 3=점4분, 4=2분)
    input       [6:0]   i_cnt
);
    localparam      C5      = 95556;
    localparam      D5      = 85132;
    localparam      E5      = 75844;
    localparam      F5      = 71586;
    localparam      G5      = 63776;
    localparam      A5      = 56818;
    localparam      B5      = 50620;
    localparam      C6      = C5/2;
    localparam      G4      = G5*2;
    localparam      REST    = 0;

    always @(*) begin
        case(i_cnt)
            // ---- song 0 : 환희의 송가 ----
            7'd0  : begin o_note = E5  ; o_len = 4'd2; end
            7'd1  : begin o_note = E5  ; o_len = 4'd2; end
            7'd2  : begin o_note = F5  ; o_len = 4'd2; end
            7'd3  : begin o_note = G5  ; o_len = 4'd2; end
            7'd4  : begin o_note = G5  ; o_len = 4'd2; end
            7'd5  : begin o_note = F5  ; o_len = 4'd2; end
            7'd6  : begin o_note = E5  ; o_len = 4'd2; end
            7'd7  : begin o_note = D5  ; o_len = 4'd2; end
            7'd8  : begin o_note = C5  ; o_len = 4'd2; end
            7'd9  : begin o_note = C5  ; o_len = 4'd2; end
            7'd10 : begin o_note = D5  ; o_len = 4'd2; end
            7'd11 : begin o_note = E5  ; o_len = 4'd2; end
            7'd12 : begin o_note = E5  ; o_len = 4'd3; end
            7'd13 : begin o_note = D5  ; o_len = 4'd1; end
            7'd14 : begin o_note = D5  ; o_len = 4'd4; end
            7'd15 : begin o_note = E5  ; o_len = 4'd2; end
            7'd16 : begin o_note = E5  ; o_len = 4'd2; end
            7'd17 : begin o_note = F5  ; o_len = 4'd2; end
            7'd18 : begin o_note = G5  ; o_len = 4'd2; end
            7'd19 : begin o_note = G5  ; o_len = 4'd2; end
            7'd20 : begin o_note = F5  ; o_len = 4'd2; end
            7'd21 : begin o_note = E5  ; o_len = 4'd2; end
            7'd22 : begin o_note = D5  ; o_len = 4'd2; end
            7'd23 : begin o_note = C5  ; o_len = 4'd2; end
            7'd24 : begin o_note = C5  ; o_len = 4'd2; end
            7'd25 : begin o_note = D5  ; o_len = 4'd2; end
            7'd26 : begin o_note = E5  ; o_len = 4'd2; end
            7'd27 : begin o_note = D5  ; o_len = 4'd3; end
            7'd28 : begin o_note = C5  ; o_len = 4'd1; end
            7'd29 : begin o_note = C5  ; o_len = 4'd4; end
            7'd30 : begin o_note = D5  ; o_len = 4'd2; end
            7'd31 : begin o_note = D5  ; o_len = 4'd2; end
            7'd32 : begin o_note = E5  ; o_len = 4'd2; end
            7'd33 : begin o_note = C5  ; o_len = 4'd2; end
            7'd34 : begin o_note = D5  ; o_len = 4'd2; end
            7'd35 : begin o_note = E5  ; o_len = 4'd1; end
            7'd36 : begin o_note = F5  ; o_len = 4'd1; end
            7'd37 : begin o_note = E5  ; o_len = 4'd2; end
            7'd38 : begin o_note = C5  ; o_len = 4'd2; end
            7'd39 : begin o_note = D5  ; o_len = 4'd2; end
            7'd40 : begin o_note = E5  ; o_len = 4'd1; end
            7'd41 : begin o_note = F5  ; o_len = 4'd1; end
            7'd42 : begin o_note = E5  ; o_len = 4'd2; end
            7'd43 : begin o_note = D5  ; o_len = 4'd2; end
            7'd44 : begin o_note = C5  ; o_len = 4'd2; end
            7'd45 : begin o_note = D5  ; o_len = 4'd2; end
            7'd46 : begin o_note = G4  ; o_len = 4'd4; end
            7'd47 : begin o_note = E5  ; o_len = 4'd2; end
            7'd48 : begin o_note = E5  ; o_len = 4'd2; end
            7'd49 : begin o_note = F5  ; o_len = 4'd2; end
            7'd50 : begin o_note = G5  ; o_len = 4'd2; end
            7'd51 : begin o_note = G5  ; o_len = 4'd2; end
            7'd52 : begin o_note = F5  ; o_len = 4'd2; end
            7'd53 : begin o_note = E5  ; o_len = 4'd2; end
            7'd54 : begin o_note = D5  ; o_len = 4'd2; end
            7'd55 : begin o_note = C5  ; o_len = 4'd2; end
            7'd56 : begin o_note = C5  ; o_len = 4'd2; end
            7'd57 : begin o_note = D5  ; o_len = 4'd2; end
            7'd58 : begin o_note = E5  ; o_len = 4'd2; end
            7'd59 : begin o_note = D5  ; o_len = 4'd3; end
            7'd60 : begin o_note = C5  ; o_len = 4'd1; end
            7'd61 : begin o_note = C5  ; o_len = 4'd4; end
            7'd62 : begin o_note = REST; o_len = 4'd4; end
            7'd63 : begin o_note = REST; o_len = 4'd0; end   // 끝 -> 처음부터 반복
            // ---- song 1 : 타이머 종료 비프 (삐 삐 삐 삐 ---) ----
            7'd64 : begin o_note = C6  ; o_len = 4'd1; end
            7'd65 : begin o_note = REST; o_len = 4'd1; end
            7'd66 : begin o_note = C6  ; o_len = 4'd1; end
            7'd67 : begin o_note = REST; o_len = 4'd1; end
            7'd68 : begin o_note = C6  ; o_len = 4'd1; end
            7'd69 : begin o_note = REST; o_len = 4'd1; end
            7'd70 : begin o_note = C6  ; o_len = 4'd1; end
            7'd71 : begin o_note = REST; o_len = 4'd5; end
            7'd72 : begin o_note = REST; o_len = 4'd0; end   // 끝 -> 반복
            default: begin o_note = REST; o_len = 4'd0; end
        endcase
    end
endmodule
