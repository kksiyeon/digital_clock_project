# digital_clock_project

기존 스위치·7세그먼트·부저에 NEC 리모컨, 16×2 문자 LCD, PSD 근접 음소거를 추가했다. 별도 저장소나 패치 없이 이 저장소만으로 컴파일할 수 있다.

| 기본 NEC 명령(hex) | 동작 |
|---|---|
| `45` | 일반 → 시계 설정 → 알람 설정 → 타이머 → 일반 |
| `46` | 설정 대상: 초 → 분 → 시 |
| `18` / `52` | 선택한 값 증가 / 감소 |
| `47` | 알람 켜기/끄기 |
| `40` | 타이머 시작 / 일시정지 / 재개 |
| `44` | 울림 정지. 울림이 없고 타이머 모드일 때는 타이머 리셋 |

명령은 예시다. 실제 리모컨에 맞춰 `src/top.v`의 `IR_*`를 설정한다. 표준 NEC 주소와 명령의 반전 바이트를 검증하며, 확장 NEC와 길게 누르기 반복 프레임은 지원하지 않는다. 특정 주소만 허용하려면 `IR_FILTER_ADDRESS=1`과 `IR_ADDRESS`를 설정한다.

## 보드 연결

- `i_ir_n`: 복조형 IR 수신기의 디지털 출력. 유휴 High이며, 미연결 시에도 High로 유지한다.
- `o_lcd_rs`, `o_lcd_rw`, `o_lcd_e`, `o_lcd_data[7:0]`: HD44780 호환 16×2 LCD, 8비트 쓰기 전용(`RW=0`). 첫째 줄은 모드, 둘째 줄은 알람 시각과 ON/OFF를 표시한다. Busy Flag를 읽지 않고 명령별 대기 시간을 사용한다.
- `o_adc_csn`, `o_adc_sclk`, `o_adc_din`, `i_adc_dout`: 보드 내장 ADC128S102. `psd_adc`가 읽은 값을 임계값과 비교해 근접 레벨을 만들고, `clock_psd_mute`가 20 ms(50 MHz) 안정화 후 울리는 동안 새로 안정된 근접만 음소거한다. 알람 ON/OFF와 타이머 설정값은 바꾸지 않는다.
- `IO_CLK_HZ`는 IR·LCD·PSD 기준 클록이며 기본 50 MHz다. 기존 시계 분주에는 영향을 주지 않는다. 핀 번호, I/O 전압, 센서 임계값, 실제 NEC 코드는 사용하는 보드와 부품에서 확인해야 한다.

## 보드 핀 배정 (quartus/digital_clock.qsf)

Quartus에서 `quartus/digital_clock.qpf`를 열면 소스(`src/`)와 핀이 모두 들어 있다. 강의 핀맵을 그대로 쓰면 겹치는 곳이 두 군데 있어서 아래처럼 정했다.

| 신호 | 핀 | 비고 |
|---|---|---|
| 모드 버튼 | sw[7] `PIN_D11` | 원래 sw[0] 자리(`PIN_C9`)를 IR 수신기가 쓰므로 옮김 |
| sw[1]~sw[6] | `D9, E11, E10, C11, B11, A12` | 설정 대상, 증가, 알람, 감소, 타이머 시작, 정지 (기존과 같음) |
| IR 수신 `i_ir_n` | `PIN_C9` | 수업 10주차 IR 핀 |
| 7-세그먼트 | GPIO-1 (`F13`…`P9`) | 수업 8주차와 같음 |
| Text LCD | GPIO-0 헤더 GPIO_0[0..10] (`D3, C3, A2, A3, B3, B4, A4, B5` = data0~7, `A5` rs, `D5` rw, `B6` e) | 수업 LCD 핀은 7-세그먼트와 같아서, LCD 케이블을 GPIO-0 헤더의 같은 위치에 꽂음 |
| 거리센서 ADC128S102 | `A10` CS, `B10` DIN, `B14` SCLK, `A9` DOUT | 보드 내장 ADC, 수업 10주차와 같음 |
| 부저 | `PIN_C8` | |

- 배선을 다르게 하면 qsf의 해당 줄만 고치면 된다.
- 시뮬레이션처럼 sw[0]을 모드 버튼으로 쓰고 싶으면 `top`의 `SW0_SHARED_WITH_IR`를 0으로 바꾸고 qsf에서 IR 대신 i_sw[0]을 `PIN_C9`에 지정한다.

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
`tb_board_io`는 ADC128S102 통신(SCLK 16번, 채널 주소, 12비트 값), 임계값 히스테리시스, 손을 가까이 했을 때 알람 울림 정지, 보드 설정에서 모드 버튼이 sw[7]인지 확인한다. 기존 두 테스트는 `SW0_SHARED_WITH_IR=0`으로 sw[0]을 모드 버튼으로 쓴다.
