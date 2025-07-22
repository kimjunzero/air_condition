`timescale 1ns / 1ps

// 습도 연동 서보모터 제어 모듈 ◀◀ 이름 변경
module servo_motor_control (
    input clk,               // 100MHz 클럭
    input reset,
    input [7:0] humidity,    // ◀◀ 수정: 습도 입력을 받음
    output servo_pwm_out      // 서보모터로 나가는 PWM 신호
);

    // --- 서보 제어를 위한 파라미터 ---
    parameter CLK_FREQ = 100_000_000;
    parameter PERIOD_20MS = CLK_FREQ / 50;    // 2,000,000 (20ms)
    
    // 0도 (문 닫힘) -> 1ms 펄스
    parameter PULSE_0_DEG = CLK_FREQ / 1000;      // 100,000 (1ms)
    // 90도 (문 열림) -> 2ms 펄스 (일반적인 서보모터 기준)
    parameter PULSE_90_DEG = CLK_FREQ / 1000 * 2; // 200,000 (2ms)

    // --- 내부 신호 ---
    reg [20:0] period_counter;
    reg [20:0] duty_cycle_count;

    // --- 로직 ---

    // 1. 주기 카운터: 20ms (50Hz) 주기를 계속 반복 (기존과 동일)
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            period_counter <= 0;
        end else if (period_counter >= PERIOD_20MS - 1) begin
            period_counter <= 0;
        end else begin
            period_counter <= period_counter + 1;
        end
    end

    // 2. 펄스 폭(Duty Cycle) 선택 ◀◀ 핵심 수정 부분
    // 습도 값에 따라 목표 각도를 결정
    always @(*) begin
        if (humidity < 60) begin
            // 습도가 60 미만이면 문 열림 (90도)
            duty_cycle_count = PULSE_90_DEG; 
        end else begin
            // 습도가 60 이상이면 문 닫힘 (0도)
            duty_cycle_count = PULSE_0_DEG;
        end
    end

    // 3. PWM 신호 생성 (기존과 동일)
    assign servo_pwm_out = (period_counter < duty_cycle_count);

endmodule