`timescale 1ns/1ps
// Standard NEC, idle high, LSB first. Repeat frames are intentionally ignored.
module ir_nec #(parameter integer CLK_HZ = 50000000) (
    input clk, rst_n, ir_n,
    output reg valid,
    output reg [7:0] address, command
);
    localparam IDLE=0, LEAD_LOW=1, LEAD_HIGH=2, BIT_LOW=3, BIT_HIGH=4, STOP_LOW=5;
    localparam integer CYCLES_PER_MS = CLK_HZ/1000;
    localparam integer TIMEOUT = 12*CYCLES_PER_MS;
    reg [2:0] state;
    (* ASYNC_REG = "TRUE" *) reg [1:0] sync;
    reg last;
    reg [$clog2(TIMEOUT+1)-1:0] elapsed;
    reg [4:0] bit_index;
    reg [31:0] frame;
    wire pin = sync[1];
    wire edge_seen = (last != pin);

    function in_window;
        input integer lo_us, hi_us;
        begin
            in_window = (elapsed >= (lo_us*CYCLES_PER_MS)/1000-1) &&
                        (elapsed <= (hi_us*CYCLES_PER_MS)/1000);
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync <= 2'b11; last <= 1; elapsed <= 0;
            state <= IDLE; bit_index <= 0; frame <= 0;
            valid <= 0; command <= 0; address <= 0;
        end else begin
            sync <= {sync[0],ir_n}; last <= pin; valid <= 0;
            if (edge_seen) begin
                elapsed <= 0;
                case (state)
                    IDLE:      if (!pin) state <= LEAD_LOW;
                    LEAD_LOW:  state <= (pin && in_window(8000,10000)) ? LEAD_HIGH : IDLE;
                    LEAD_HIGH: begin
                        state <= !pin && in_window(3800,5200) ? BIT_LOW : IDLE;
                        bit_index <= 0;
                    end
                    BIT_LOW:   state <= (pin && in_window(350,800)) ? BIT_HIGH : IDLE;
                    BIT_HIGH:  if (!pin && (in_window(350,800) || in_window(1250,2000))) begin
                        frame[bit_index] <= in_window(1250,2000);
                        bit_index <= bit_index + 1'b1;
                        state <= (bit_index == 31) ? STOP_LOW : BIT_LOW;
                    end else state <= IDLE;
                    STOP_LOW: begin
                        state <= IDLE;
                        if (pin && in_window(350,800) &&
                            frame[7:0] == ~frame[15:8] && frame[23:16] == ~frame[31:24]) begin
                            address <= frame[7:0]; command <= frame[23:16]; valid <= 1;
                        end
                    end
                    default: state <= IDLE;
                endcase
            end else if (elapsed == TIMEOUT-1) begin
                state <= IDLE;
            end else elapsed <= elapsed + 1'b1;
        end
    end
endmodule
