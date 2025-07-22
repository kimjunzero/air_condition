`timescale 1ns / 1ps

// NOTE: 50% 고정 듀티 사이클 PWM 생성 모듈
module microwave_pwm_motor_control (
    input        clk,
    // duty_inc, duty_dec 입력 삭제
    output [3:0] DUTY_CYCLE,
    output       pwm_out       // 10MHz PWM output signal 
); 

    // 50% 고정 듀티 사이클 (0~9 카운터 기준 5)
    localparam FIXED_DUTY = 5;

    reg [3:0] r_counter_PWM = 0; // 10MHz PWM 신호 생성을 위한 카운터

    // 10MHz PWM 주기를 위한 카운터 (100MHz clk 기준 0~9 반복)
    always @(posedge clk) begin
        if (r_counter_PWM >= 9) begin
            r_counter_PWM <= 0;
        end else begin
            r_counter_PWM <= r_counter_PWM + 1;
        end
    end

    // 최종 출력
    assign pwm_out    = (r_counter_PWM < FIXED_DUTY);
    assign DUTY_CYCLE = FIXED_DUTY;
    
endmodule