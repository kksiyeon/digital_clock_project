// ==================================================
//  * Filename      : psd_adc.v
//  * Description   : 거리센서(GP2Y0A21) 값을 DE0-Nano 내장 ADC128S102 에서 읽어
//                    "가까움" 레벨(o_near)로 바꿈
//
//  수업 10주차 psd.v 와 달라진 점
//   1) SCLK 를 별도 클럭으로 쓰지 않고 50MHz i_clk 하나로 SPI 신호를 만듦
//      (SCLK = i_clk / (2*SCLK_HALF), 기본 50MHz/6 = 약 8.3MHz)
//   2) 12비트 값을 끝까지(DB0 포함) 받은 뒤 한 번에 o_data 갱신
//   3) 임계값 + 히스테리시스로 o_near 출력
//      GP2Y0A21 은 가까울수록 전압(값)이 큼: TH_ON 이상 -> 가까움, TH_OFF 이하 -> 멀어짐
//      실제 값은 보드에서 확인 후 top 의 PSD_TH_ON / PSD_TH_OFF 로 조정
//
//  ADC128S102 프레임 (CS 낮은 동안 SCLK 16번)
//   - DIN : 3~5번째 클럭에 채널 주소 ADD2..0 (상승 에지에서 ADC가 읽음)
//   - DOUT: 앞 4비트 0, 이후 12비트 MSB 먼저 (하강 에지에서 바뀜 -> 상승 에지에서 읽음)
// ==================================================
module  psd_adc
#(
    parameter integer   SCLK_HALF = 3,      // SCLK 반주기 (i_clk 개수)
    parameter [2:0]     CHANNEL   = 3'd0,   // 센서가 연결된 ADC 채널
    parameter [11:0]    TH_ON     = 12'd2000,
    parameter [11:0]    TH_OFF    = 12'd1600
)
(
    output reg          o_csn,
    output reg          o_sclk,
    output reg          o_din,
    output reg  [11:0]  o_data,
    output reg          o_valid,            // 새 값이 들어온 클럭에 1
    output reg          o_near,
    input               i_dout,
    input               i_clk,
    input               i_rstn
);
    localparam integer HALF_W = (SCLK_HALF < 2) ? 1 : $clog2(SCLK_HALF);

    reg [HALF_W-1:0] div;
    reg [4:0]        bit_cnt;               // 0~15: 비트, 16: CS 높게 쉬는 구간
    reg [15:0]       shift;

    always @(posedge i_clk or negedge i_rstn) begin
        if(!i_rstn) begin
            div       <= 0;
            bit_cnt   <= 5'd16;
            shift     <= 16'd0;
            o_csn     <= 1'b1;
            o_sclk    <= 1'b1;
            o_din     <= 1'b0;
            o_data    <= 12'd0;
            o_valid   <= 1'b0;
            o_near    <= 1'b0;
        end else begin
            o_valid   <= 1'b0;
            if(div != SCLK_HALF - 1) begin
                div <= div + 1'b1;
            end else begin
                div <= 0;
                if(bit_cnt == 5'd16) begin
                    // 한 프레임 끝: CS 를 한 반주기 높게 두었다가 다시 시작
                    if(o_csn) begin
                        o_csn   <= 1'b0;
                        bit_cnt <= 5'd0;
                    end else begin
                        o_csn   <= 1'b1;
                    end
                end else if(o_sclk) begin
                    // 하강 에지: ADC 가 DOUT 을 내보내고, 우리는 DIN 을 바꿈
                    o_sclk <= 1'b0;
                    case(bit_cnt)
                        5'd2:    o_din <= CHANNEL[2];
                        5'd3:    o_din <= CHANNEL[1];
                        5'd4:    o_din <= CHANNEL[0];
                        default: o_din <= 1'b0;
                    endcase
                end else begin
                    // 상승 에지: DOUT 읽기
                    o_sclk  <= 1'b1;
                    shift   <= {shift[14:0], i_dout};
                    bit_cnt <= bit_cnt + 1'b1;
                    if(bit_cnt == 5'd15) begin
                        o_data  <= {shift[10:0], i_dout};
                        o_valid <= 1'b1;
                        if(!o_near && {shift[10:0], i_dout} >= TH_ON)  o_near <= 1'b1;
                        if( o_near && {shift[10:0], i_dout} <= TH_OFF) o_near <= 1'b0;
                    end
                end
            end
        end
    end
endmodule
