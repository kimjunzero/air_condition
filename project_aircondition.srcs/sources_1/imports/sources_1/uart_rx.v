`timescale 1ns / 1ps

module uart_rx(
    input clk,
    input reset,
    input rx,

    output reg [7:0]    data_out,
    output reg          rxdone
    );

    parameter
        IDLE =      2'b00,
        START_BIT = 2'b01,
        DATA_BITS = 2'b10,
        STOP_BIT =  2'b11;

    // 16x 오버샘플링: 9600 baud * 16 = 153600 Hz
    parameter integer DIVIDER_COUNT = 100_000_000 / (9600 * 16);

    reg [1:0]   r_state;
    reg [3:0]   r_bit_cnt;
    reg [7:0]   r_datareg;
    reg [15:0]  r_baud_cnt;
    reg         r_baud_tick;
    reg [3:0]   r_baud_tick_cnt;

    // 16x 오버샘플링 틱 생성기
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_baud_cnt <= 0;
            r_baud_tick <= 0;
        end else begin
            if (r_baud_cnt == DIVIDER_COUNT - 1) begin
                r_baud_cnt <= 0;
                r_baud_tick <= 1;
            end else begin
                r_baud_cnt <= r_baud_cnt + 1;
                r_baud_tick <= 0;
            end
        end
    end

    // UART RX FSM
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_state <= IDLE;
            r_bit_cnt <= 0;
            r_datareg <= 0;
            r_baud_tick_cnt <= 0;
            data_out <= 0;
            rxdone <= 0;
        end else begin
            case (r_state)
                IDLE: begin
                    rxdone <= 0;
                    r_baud_tick_cnt <= 0;
                    r_bit_cnt <= 0;
                    
                    // START BIT 감지 (rx가 0으로 떨어짐)
                    if (rx == 1'b0) begin
                        r_state <= START_BIT;
                        r_baud_tick_cnt <= 0;
                    end
                end

                START_BIT: begin
                    if (r_baud_tick) begin
                        if (r_baud_tick_cnt == 4'd7) begin
                            // START BIT 중간 지점에서 확인
                            r_state <= DATA_BITS;
                            r_bit_cnt <= 0;
                            r_baud_tick_cnt <= 0;
                        end else begin
                            r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                        end
                    end
                end

                DATA_BITS: begin
                    if (r_baud_tick) begin
                        if (r_baud_tick_cnt == 4'd15) begin
                            // 각 데이터 비트의 중간 지점에서 샘플링
                            r_datareg[r_bit_cnt] <= rx;
                            r_baud_tick_cnt <= 0;
                            
                            if (r_bit_cnt == 4'd7) begin
                                // 8비트 모두 수신 완료
                                r_state <= STOP_BIT;
                            end else begin
                                r_bit_cnt <= r_bit_cnt + 1;
                            end
                        end else begin
                            r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                        end
                    end
                end

                STOP_BIT: begin
                    if (r_baud_tick) begin
                        if (r_baud_tick_cnt == 4'd15) begin
                            // STOP BIT 중간 지점에서 수신 완료
                            r_state <= IDLE;
                            data_out <= r_datareg;     // 수신된 데이터 출력
                            rxdone <= 1'b1;            // 수신 완료 플래그
                        end else begin
                            r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                        end
                    end
                end

                default: r_state <= IDLE;
            endcase
        end
    end

endmodule