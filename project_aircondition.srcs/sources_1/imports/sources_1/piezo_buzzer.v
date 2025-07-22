`timescale 1ns / 1ps

module dht11_top(
    // 시스템 입력
    input clk,
    input reset,
    input btnU, btnL, btnC, btnR, btnD,
    input [7:0] sw,
    
    // UART
    input RsRx,
    output RsTx,
    
    // 센서들
    inout dht11_data,
    input ECHO,
    output TRIG,
    
    // 디스플레이 및 기타 출력
    output [7:0] seg,
    output [3:0] an,
    output [14:0] led,
    output buzzer,

    // DC 모터 제어
    input [1:0] motor_direction,
    output pwm_out,
    output [1:0] in1_in2,

    // 서보모터 제어
    output servo_pwm_out
);

    // --- 내부 신호 ---
    wire [7:0] temperature;
    wire [7:0] humidity;
    wire [7:0] distance_cm;
    wire w_btnU, w_btnL, w_btnD, w_btnC, w_btnR;
    
    wire dht11_done_raw;
    wire ultrasonic_done_raw;
    
    reg [1:0] display_mode;
    
    wire [7:0] uart_rx_data;
    wire uart_rx_done;

    reg [1:0] motor_direction_reg;

    wire internal_motor_pwm_out;
    wire [1:0] internal_in1_in2;

    reg dht11_done_d1 = 0;
    reg ultrasonic_done_d1 = 0;
    reg prev_w_btnC = 0;

    wire dht11_done_pulse = dht11_done_raw & ~dht11_done_d1;
    wire ultrasonic_done_pulse = ultrasonic_done_raw & ~ultrasonic_done_d1;

    // ◀◀ MUX를 위한 신호 선언
    wire danger_close;
    wire button_buzzer_signal;  // 버튼 부저 모듈의 출력
    wire warning_buzzer_signal; // 경고 부저 모듈의 출력

    // 거리가 5cm 미만이면 danger_close 신호를 1로 설정 (MUX 선택 신호로 사용)
    assign danger_close = (distance_cm < 5);


    always @(posedge clk) begin
        dht11_done_d1 <= dht11_done_raw;
        ultrasonic_done_d1 <= ultrasonic_done_raw;
    end

    // 1. 버튼 디바운싱
    button_debounce u_btnU_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnU), .o_btn_clean(w_btnU));
    button_debounce u_btnC_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnC), .o_btn_clean(w_btnC));
    button_debounce u_btnR_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnR), .o_btn_clean(w_btnR));
    button_debounce u_btnD_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnD), .o_btn_clean(w_btnD));
    button_debounce u_btnL_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnL), .o_btn_clean(w_btnL));
    
    // ◀◀ 수정: 2개의 부저 모듈 각각 인스턴스화
    // 1-1. 버튼 입력용 부저
    piezo_buzzer u_piezo_buzzer(
        .clk(clk), 
        .reset(reset), 
        .btnU(w_btnU), .btnC(w_btnC), .btnR(w_btnR), .btnD(w_btnD), .btnL(w_btnL), 
        .buzzer(button_buzzer_signal) // 버튼 부저 신호에 연결
    );

    // 1-2. 거리 경고용 부저
    warning_buzzer u_warning_buzzer(
        .clk(clk), 
        .reset(reset), 
        .danger_close(danger_close), 
        .buzzer_out(warning_buzzer_signal) // 경고 부저 신호에 연결
    );
    
    // 2. DHT11 센서 모듈
    dht11_sensor u_dht11_sensor (.clk(clk), .rst_n(~reset), .dht11_data(dht11_data), .humidity(humidity), .temperature(temperature), .DHT11_done(dht11_done_raw));

    // 3. 초음파 센서 모듈
    ultrasonic_check u_ultrasonic (.clk(clk), .reset(reset), .echo(ECHO), .trig(TRIG), .distance(distance_cm), .done(ultrasonic_done_raw));
    
    // 4. UART 관리 모듈
    uart_manager u_uart_manager(.clk(clk), .reset(reset), .temperature(temperature), .humidity(humidity), .distance(distance_cm), .manual_data(sw), .display_mode(display_mode), .dht11_done(dht11_done_pulse), .ultrasonic_done(ultrasonic_done_pulse), .rx(RsRx), .tx(RsTx), .rx_data(uart_rx_data), .rx_done(uart_rx_done));

    // 5. 디스플레이 제어 모듈
    display_controller u_display_controller(.clk(clk), .reset(reset), .temperature(temperature), .humidity(humidity), .distance(distance_cm), .manual_data(sw), .display_mode(display_mode), .seg(seg), .an(an));

    // 6. 온도 기반 자동 PWM 제어 모듈
    pwm_motor_control u_pwm_motor_control(.clk(clk), .reset(~reset), .motor_direction(motor_direction_reg), .temperature(temperature), .pwm_out(internal_motor_pwm_out), .in1_in2(internal_in1_in2));

    // 7. 습도 연동 서보모터 모듈
    servo_motor_control u_servo_motor_control (
        .clk(clk),
        .reset(reset),
        .humidity(humidity),          // ◀◀ DHT11의 습도 신호를 여기에 연결
        .servo_pwm_out(servo_pwm_out) // ◀◀ 최종 서보 PWM 출력을 XDC 파일에 설정된 핀으로 연결
    );
    // --- 제어 및 LED 로직 ---
    always @(posedge clk or posedge reset) begin
        if (btnU) begin
            display_mode <= 0;
            prev_w_btnC  <= 0;
            motor_direction_reg <= 2'b00;
        end else begin
            prev_w_btnC <= w_btnC;

            if (w_btnC && !prev_w_btnC) begin
                display_mode <= (display_mode == 2) ? 0 : display_mode + 1;
            end
            
            if (uart_rx_done) begin
                case (uart_rx_data)
                    8'h41, 8'h61: display_mode <= 0;
                    8'h4d, 8'h6d: display_mode <= 1;
                    8'h44, 8'h64: display_mode <= 2;
                endcase
            end

            // 장애물 감지 시 모터 강제 정지
            if (danger_close) begin
                motor_direction_reg <= 2'b00; 
            end 
            else begin 
                case (motor_direction[1:0])
                    2'b00: motor_direction_reg <= 2'b00;
                    2'b01: motor_direction_reg <= 2'b01;
                    2'b10: motor_direction_reg <= 2'b10;
                    default: motor_direction_reg <= 2'b00;
                endcase
            end
        end
    end
    
    // LED 및 모터 출력 제어
    assign led[1:0]   = display_mode;
    assign led[3:2]   = motor_direction_reg;
    assign led[11]    = ultrasonic_done_pulse;
    assign led[12]    = dht11_done_pulse;
    assign led[10:4]  = 7'b0;
    assign led[14:13] = 2'b0;

    assign pwm_out = internal_motor_pwm_out;
    assign in1_in2 = internal_in1_in2;

    // ◀◀ 수정: 부저 MUX 로직
    // danger_close가 1이면 경고음, 아니면 버튼음을 최종 buzzer 출력으로 선택
    assign buzzer = danger_close ? warning_buzzer_signal : button_buzzer_signal;

endmodule