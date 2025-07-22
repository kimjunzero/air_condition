`timescale 1ns / 1ps

module ultrasonic_check (
    input            clk,        // 100 MHz
    input            reset,      // active-high
    input            echo,       // HC-SR04 echo
    output reg       trig,       // HC-SR04 trig
    output reg [7:0] distance,   // cm 단위
    output reg       done        // 1clk 펄스
);

    // FSM 상태
    parameter IDLE       = 3'd0,
              TRIG_HIGH  = 3'd1,
              WAIT_ECHO  = 3'd2,
              MEASURING  = 3'd3,
              DONE_STATE = 3'd4;

    reg [2:0]  state;
    reg [31:0] trig_cnt, echo_cnt, cycle_cnt, timeout_cnt;
    reg        echo_d;

    // 타이밍 상수 (100 MHz 기준)
    parameter TRIG_CLKS    = 1_000;       // 10 µs
    parameter CYCLE_CLKS   = 50_000_000;  // 500 ms
    parameter TIMEOUT_CLKS = 3_000_000;   //  30 ms

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            trig        <= 1'b0;
            distance    <= 8'd0;
            done        <= 1'b0;
            trig_cnt    <= 0;
            echo_cnt    <= 0;
            cycle_cnt   <= 0;
            timeout_cnt <= 0;
            echo_d      <= 1'b0;
        end else begin
            echo_d <= echo;
            done   <= 1'b0;  // default

            case (state)
                IDLE: begin
                    trig <= 1'b0;
                    if (cycle_cnt >= CYCLE_CLKS) begin
                        cycle_cnt   <= 0;
                        trig        <= 1'b1;
                        trig_cnt    <= 1;
                        timeout_cnt <= 0;
                        state       <= TRIG_HIGH;
                    end else
                        cycle_cnt <= cycle_cnt + 1;
                end

                TRIG_HIGH: begin
                    if (trig_cnt < TRIG_CLKS) begin
                        trig     <= 1'b1;
                        trig_cnt <= trig_cnt + 1;
                    end else begin
                        trig  <= 1'b0;
                        state <= WAIT_ECHO;
                    end
                end

                WAIT_ECHO: begin
                    // rising edge 감지
                    if (echo && !echo_d) begin
                        echo_cnt    <= 0;
                        timeout_cnt <= 0;
                        state       <= MEASURING;
                    end
                    // 타임아웃
                    else if (timeout_cnt < TIMEOUT_CLKS) begin
                        timeout_cnt <= timeout_cnt + 1;
                    end else begin
                        state <= IDLE;
                    end
                end

                MEASURING: begin
                    if (echo) begin
                        echo_cnt    <= echo_cnt + 1;
                        timeout_cnt <= 0;
                    end
                    // falling edge: 측정 완료
                    else if (!echo && echo_d) begin
                        distance <= echo_cnt / 5800;  // cm 환산
                        done     <= 1'b1;
                        state    <= DONE_STATE;
                    end
                    // 타임아웃
                    else if (timeout_cnt < TIMEOUT_CLKS) begin
                        timeout_cnt <= timeout_cnt + 1;
                    end else begin
                        state <= IDLE;
                    end
                end

                DONE_STATE: begin
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
