`timescale 1ns / 1ps

// Module: temp_to_pwm_auto
// Function: 온도(temp_celsius) 입력에 따라 DC 모터의 PWM 신호를 자동 생성
// - System Clock: 100MHz
// - PWM Frequency: 25kHz (주기 40,000ns)
module pwm_motor_control (
    input               clk,          // 100MHz 시스템 클럭
    input               reset,        // Active-low 리셋
    input      [1:0]    motor_direction, // 스위치 입력
    input      [7:0]    temperature, // DHT11 등에서 받은 섭씨 온도 값
    output reg          pwm_out,
    output reg [1:0]    in1_in2        // 모터 드라이버로 정방향/ 역방향 출력
);

    // ## 파라미터 설정 (수정 용이) ##
    // PWM 주기 설정 (100MHz 클럭 기준 25kHz PWM 생성)
    // 40,000ns / 10ns = 4000
    parameter PWM_PERIOD = 4000; 
    
    // 온도 단계별 임계값 설정
    parameter TEMP_LV1 = 24; // 24도 이하
    parameter TEMP_LV2 = 27; // 25도 ~ 27도
    parameter TEMP_LV3 = 30; // 28도 ~ 30도
    // 31도 이상은 최고 속도

    // 내부 신호
    reg [11:0] pwm_counter = 0; // PWM 주기를 위한 카운터 (4000까지 카운트 -> 12비트)
    reg [11:0] duty_reg = 0;    // PWM 듀티비를 저장할 레지스터

    // 1. PWM 주기를 만드는 카운터 (25kHz)
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            pwm_counter <= 0;
        end else if (pwm_counter >= PWM_PERIOD - 1) begin
            pwm_counter <= 0;
        end else begin
            pwm_counter <= pwm_counter + 1;
        end
    end
    
    // 2. 온도(temp_celsius)에 따라 duty_reg 값을 자동으로 결정하는 로직
    always @(*) begin
        if (temperature <= TEMP_LV1) begin
            duty_reg = 0; // 팬 정지 (Duty 0%)
        end
        else if (temperature <= TEMP_LV2) begin
            duty_reg = PWM_PERIOD / 4; // 약한 바람 (Duty 25%)
        end
        else if (temperature <= TEMP_LV3) begin
            duty_reg = PWM_PERIOD / 2; // 중간 바람 (Duty 50%)
        end
        else begin // TEMP_LV3 보다 높을 때
            duty_reg = PWM_PERIOD; // 강한 바람 (Duty 100%)
        end
    end

    // 3. 카운터와 듀티비를 비교하여 최종 PWM 신호 출력 (속도 제어)
    // 이 pwm_out은 H-bridge의 Enable 핀에 연결될 예정
    always @(*) begin
        if (motor_direction == 2'b00) begin // 정지 명령일 경우 PWM도 0으로 (모터 완전 정지)
            pwm_out = 1'b0;
        end else begin
            pwm_out = (pwm_counter < duty_reg);
        end
    end

    // 4. motor_direction 입력에 따라 in1_in2 신호 결정 (방향 제어)
    // 이 in1_in2는 H-bridge의 IN1, IN2 핀에 연결될 예정
    always @(*) begin
        case (motor_direction)
            2'b01: in1_in2 = 2'b01; // 정방향 (예: IN1=1, IN2=0)
            2'b10: in1_in2 = 2'b10; // 역방향 (예: IN1=0, IN2=1)
            default: in1_in2 = 2'b00; // 정지 (00: IN1=0, IN2=0 또는 H-bridge에 따라 11)
        endcase
    end

endmodule
