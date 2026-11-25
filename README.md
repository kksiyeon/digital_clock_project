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
- `i_psd_near`: 비교기나 ADC가 내보낸 **디지털** 근접 신호만 받는다. 기본 근접 High, 안정화 20 ms(50 MHz). 미연결 시 원거리 레벨로 유지한다. 울리는 동안 새로 안정된 근접만 음소거하며 알람 ON/OFF와 타이머 설정값은 바꾸지 않는다.
- `IO_CLK_HZ`는 IR·LCD·PSD 기준 클록이며 기본 50 MHz다. 기존 시계 분주에는 영향을 주지 않는다. 핀 번호, I/O 전압, 센서 임계값, 실제 NEC 코드는 사용하는 보드와 부품에서 확인해야 한다.

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
```

기존 두 테스트는 스위치, 시계 설정, 깜빡임, 알람과 타이머를 확인한다. 통합 테스트는 리모컨 7개 버튼과 무효 프레임, LCD 초기화와 두 줄 쓰기, PSD의 짧은 펄스 차단 및 알람·타이머 음소거를 확인한다.
