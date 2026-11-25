# digital_clock_project

기존 스위치·7세그먼트·부저에 NEC 리모컨, 16×2 문자 LCD, PSD 근접 음소거를 추가했다. 별도 저장소나 패치 없이 이 저장소만으로 컴파일할 수 있다.

수업 리모컨(LY, 21키) 기준 버튼 배치. 코드값은 같은 칩을 쓰는 21키 리모컨의 버튼 위치별 코드로 **추정**한 값이다.

| 리모컨 버튼 | NEC 명령 hex (10진) | 동작 (같은 키스위치) |
|---|---|---|
| MENU | `47` (71) | 모드 바꾸기 (sw[0]) |
| ◀ / ▶ | `07` (7) / `09` (9) | 설정 대상 초 → 분 → 시 (sw[1]) |
| + / ▲ | `44` (68) / `40` (64) | 선택한 값 +1 (sw[2]) |
| − / ▼ | `16` (22) / `19` (25) | 선택한 값 −1 (sw[4]) |
| 전원 | `45` (69) | 알람 켜기/끄기 (sw[3]) |
| OK | `15` (21) | 타이머 시작 / 일시정지 / 재개 (sw[5]) |
| ↩ | `43` (67) | 울림 정지, 안 울릴 때 타이머 모드면 리셋 (sw[6]) |
| 0~9 | | 사용 안 함 |

**코드 확인 화면:** sw[7]을 누르면 7-세그먼트 점 6개가 켜지고 마지막으로 받은 리모컨 코드가 10진수로 나온다 (왼쪽 3자리 주소, 오른쪽 3자리 명령). 다시 누르면 원래 화면. 버튼이 안 먹으면 여기서 본 명령 값을 `src/top.v`의 `IR_*` 파라미터에 넣는다 (`8'd71`처럼 10진수로 써도 됨). 표준 NEC 주소와 명령의 반전 바이트를 검증하며, 길게 누르기 반복 프레임은 무시한다. 특정 주소만 허용하려면 `IR_FILTER_ADDRESS=1`과 `IR_ADDRESS`를 설정한다.

## 보드 연결

- `i_ir_n`: 복조형 IR 수신기의 디지털 출력. 유휴 High이며, 미연결 시에도 High로 유지한다.
- `o_lcd_rs`, `o_lcd_rw`, `o_lcd_e`, `o_lcd_data[7:0]`: HD44780 호환 16×2 LCD, 8비트 쓰기 전용(`RW=0`). 첫째 줄은 모드, 둘째 줄은 알람 시각과 ON/OFF를 표시한다. Busy Flag를 읽지 않고 명령별 대기 시간을 사용한다.
- `o_adc_csn`, `o_adc_sclk`, `o_adc_din`, `i_adc_dout`: 보드 내장 ADC128S102. `psd_adc`가 읽은 값을 임계값과 비교해 근접 레벨을 만들고, `clock_psd_mute`가 20 ms(50 MHz) 안정화 후 울리는 동안 새로 안정된 근접만 음소거한다. 알람 ON/OFF와 타이머 설정값은 바꾸지 않는다.
- `IO_CLK_HZ`는 IR·LCD·PSD 기준 클록이며 기본 50 MHz다. 기존 시계 분주에는 영향을 주지 않는다. 핀 번호, I/O 전압, 센서 임계값, 실제 NEC 코드는 사용하는 보드와 부품에서 확인해야 한다.

## 보드 연결 (quartus/digital_clock.qsf)

Quartus에서 `quartus/digital_clock.qpf`를 열면 소스(`src/`)와 핀이 모두 들어 있다. 실습 보드(HBE-CapstoneMulti)의 각 모듈 케이블을 AVR-STACK의 아래 커넥터에 꽂는다. STACK 커넥터 위의 숫자표가 GPIO 번호다.

| 모듈 (케이블) | STACK 커넥터 | DE0-Nano 핀 | 비고 |
|---|---|---|---|
| 7-세그먼트 J3 (A~G, DP) | J10 (FPGA GPIO-1 0~7) | F13, T15, T14, T13, R13, T12, R12, T11 | 수업 8주차와 같음 |
| 7-세그먼트 J4 (S0~S5) | J11 (FPGA GPIO-1 8~15) | T10, R11, P11, R10, N12, P9 | 수업 8주차와 같음 |
| 키스위치 | J20 (FPGA GPIO-0 24~31) | sw[0]~sw[7] = C9, D9, E11, E10, C11, B11, A12, D11 | 수업 8~9주차와 같음 |
| 부저 | FPGA GPIO-0 16~23 커넥터 | C8 (GPIO_0[16]) | 수업 9주차와 같음 |
| IR 수신 | **J12 (FPGA GPIO-1 16~23)** | L16 (GPIO_1[16]) | 수업 10주차는 J20(C9)이었지만 키스위치와 겹쳐서 옮김 |
| 거리센서(PSD) | J14 (FPGA GPIO-2, A0~) | ADC: A10 CS, B10 DIN, B14 SCLK, A9 DOUT | 수업 10주차와 같음, ADC 채널 0 |
| Text LCD 데이터 | **FPGA GPIO-0 0~7 커넥터** | D3, C3, A2, A3, B3, B4, A4, B5 (data0~7) | 수업 11주차는 J10이었지만 7-세그먼트와 겹쳐서 옮김 |
| Text LCD 제어 | **FPGA GPIO-0 8~15 커넥터** | A5 rs, D5 rw, B6 e | 수업 11주차는 J11이었지만 7-세그먼트와 겹쳐서 옮김 |

- 키는 수업과 같다: sw[0] 모드 / sw[1] 설정 대상 / sw[2] 증가 / sw[3] 알람 / sw[4] 감소 / sw[5] 타이머 시작·일시정지 / sw[6] 정지 / sw[7] 리모컨 코드 확인 화면.
- 배선을 다르게 하면 qsf의 해당 줄만 고치면 된다. IR을 수업처럼 J20(C9)에 꽂아야 하면 `top`의 `SW0_SHARED_WITH_IR`를 1로 바꾸고(모드 = sw[7]) qsf에서 `i_ir_n`을 `PIN_C9`, `i_sw[0]` 줄은 지운다.
- LCD 밝기: 수업 11주차처럼 STACK 전원 스위치를 5V로 두고 LCD 전원 케이블을 연결한다.

## 거리센서 (src/psd_adc.v)

- 보드 내장 ADC128S102를 50 MHz 클럭 하나로 SPI 통신해서 읽는다 (SCLK 약 8.3 MHz, 채널 `PSD_ADC_CH` 기본 0).
- 값이 `PSD_TH_ON`(기본 2000) 이상이면 가까움, `PSD_TH_OFF`(기본 1600) 이하이면 멀어짐으로 판단한다. GP2Y0A21은 가까울수록 값이 크다.
- 가까움이 20 ms 유지되면 `clock_psd_mute`가 울림만 끈다. 임계값은 보드에서 실제 값을 보고 조정해야 한다.

## 시뮬레이션

저장소 루트에서 Icarus Verilog로 실행한다.

```sh
set -e
iverilog -g2012 -s tb_top -o /tmp/tb_top src/*.v src/class/*.v sim/tb_top.v
vvp /tmp/tb_top
iverilog -g2012 -s tb_alarm_timer -o /tmp/tb_alarm_timer src/*.v src/class/*.v sim/tb_alarm_timer.v
vvp /tmp/tb_alarm_timer
iverilog -g2012 -s tb_team_clock_io -o /tmp/tb_team_clock_io src/*.v src/class/*.v sim/tb_team_clock_io.sv
vvp /tmp/tb_team_clock_io
iverilog -g2012 -s tb_board_io -o /tmp/tb_board_io src/*.v src/class/*.v sim/tb_board_io.v
vvp /tmp/tb_board_io
```

기존 두 테스트는 스위치, 시계 설정, 깜빡임, 알람과 타이머를 확인한다. 통합 테스트는 리모컨 7개 버튼과 무효 프레임, LCD 초기화와 두 줄 쓰기, PSD의 짧은 펄스 차단 및 알람·타이머 음소거를 확인한다.
`tb_board_io`는 ADC128S102 통신(SCLK 16번, 채널 주소, 12비트 값), 임계값 히스테리시스, 손을 가까이 했을 때 알람 울림 정지, 보드 기본 설정에서 모드 버튼이 sw[0]인지 확인한다.
