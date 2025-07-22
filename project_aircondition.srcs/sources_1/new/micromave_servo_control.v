`timescale 1ns / 1ps

// 서보모터 제어 모듈
module microwave_servo_control (
    input clk,           // 100MHz 클럭
    input reset,
    input door_switch,   // 문 열림/닫힘 제어 스위치 (SW13)
    output servo_pwm_out // 서보모터로 나가는 PWM 신호
);

    // --- 서보 제어를 위한 파라미터 ---
    parameter CLK_FREQ = 100_000_000;
    parameter PERIOD_20MS = CLK_FREQ / 50; // 2,000,000 (20ms)

    // 0도 (문 닫힘) -> 1ms 펄스
    parameter PULSE_0_DEG = CLK_FREQ / 1000 * 1; // 100,000

    // 90도 (문 열림) -> 1.5ms 펄스로 정확하게 수정
    parameter PULSE_90_DEG = CLK_FREQ / 1000 * 2; // 150,000

    // --- 내부 신호 ---
    reg [20:0] period_counter;
    reg [20:0] duty_cycle_count;

    // --- 로직 ---
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            period_counter <= 0;
        end else if (period_counter >= PERIOD_20MS - 1) begin
            period_counter <= 0;
        end else begin
            period_counter <= period_counter + 1;
        end
    end

    always @(*) begin
        if (door_switch) begin
            duty_cycle_count = PULSE_90_DEG; // 스위치 ON -> 문 열림 (90도)
        end else begin
            duty_cycle_count = PULSE_0_DEG;  // 스위치 OFF -> 문 닫힘 (0도)
        end
    end

    assign servo_pwm_out = (period_counter < duty_cycle_count);

endmodule
