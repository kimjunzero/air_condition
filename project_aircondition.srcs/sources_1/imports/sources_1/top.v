`timescale 1ns / 1ps

module aircondition_mode(
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

    // 서보 모터 제어
    output servo_pwm_out
);

    // --- 내부 신호 ---
    wire [7:0] temperature;
    wire [7:0] humidity;
    wire [7:0] distance_cm;
    wire w_btnU, w_btnL, w_btnD, w_btnC, w_btnR;
    
    wire dht11_done_raw;
    wire ultrasonic_done_raw;
    
    wire [7:0] uart_rx_data;
    wire uart_rx_done;

    wire internal_motor_pwm_out;
    wire [1:0] internal_in1_in2;
    wire servo_pwm_out_internal;

    reg dht11_done_d1 = 0;
    reg ultrasonic_done_d1 = 0;

    wire dht11_done_pulse = dht11_done_raw & ~dht11_done_d1;
    wire ultrasonic_done_pulse = ultrasonic_done_raw & ~ultrasonic_done_d1;

    wire danger_close;
    wire button_buzzer_signal;
    wire warning_buzzer_signal;

    // FSM과의 연결을 위한 신호
    wire [2:0] fsm_display_mode;
    wire [7:0] fsm_manual_value;
    wire [1:0] fsm_dc_motor_direction;
    wire [7:0] fsm_dc_motor_temp_in;
    wire fsm_servo_active;

    // --- 로직 및 모듈 인스턴스화 ---

    assign danger_close = (distance_cm < 5);

    always @(posedge clk) begin
        dht11_done_d1 <= dht11_done_raw;
        ultrasonic_done_d1 <= ultrasonic_done_raw;
    end

    // 1. 버튼 디바운싱 및 부저 모듈들
    button_debounce u_btnU_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnU), .o_btn_clean(w_btnU));
    button_debounce u_btnC_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnC), .o_btn_clean(w_btnC));
    button_debounce u_btnR_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnR), .o_btn_clean(w_btnR));
    button_debounce u_btnD_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnD), .o_btn_clean(w_btnD));
    button_debounce u_btnL_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnL), .o_btn_clean(w_btnL));
    
    piezo_buzzer u_piezo_buzzer(.clk(clk), .reset(reset), .btnU(w_btnU), .btnC(w_btnC), .btnR(w_btnR), .btnD(w_btnD), .btnL(w_btnL), .buzzer(button_buzzer_signal));
    warning_buzzer u_warning_buzzer(.clk(clk), .reset(reset), .danger_close(danger_close), .buzzer_out(warning_buzzer_signal));
    
    // 2. 센서 모듈들
    dht11_sensor u_dht11_sensor (.clk(clk), .rst_n(~reset), .dht11_data(dht11_data), .humidity(humidity), .temperature(temperature), .DHT11_done(dht11_done_raw));
    ultrasonic_check u_ultrasonic (.clk(clk), .reset(reset), .echo(ECHO), .trig(TRIG), .distance(distance_cm), .done(ultrasonic_done_raw));
    
    // 3. 통신 및 디스플레이 모듈들
    uart_manager u_uart_manager(
        .clk(clk), 
        .reset(reset), 
        .temperature(temperature), 
        .humidity(humidity), 
        .distance(distance_cm), 
        .rx(RsRx), 
        .tx(RsTx), 
        .rx_data(uart_rx_data), 
        .rx_done(uart_rx_done)
    );
    
    display_controller u_display_controller(
        .clk(clk), 
        .reset(reset), 
        .temperature(temperature), 
        .humidity(humidity), 
        .distance(distance_cm), 
        .display_mode(fsm_display_mode), // FSM 출력 연결
        .manual_value(fsm_manual_value), // FSM 출력 연결
        .seg(seg), 
        .an(an)
    );

    // 4. 모터 제어 모듈들
    pwm_motor_control u_pwm_motor_control(
        .clk(clk), 
        .reset(~reset), 
        .motor_direction(fsm_dc_motor_direction), // FSM 출력 연결
        .temperature(fsm_dc_motor_temp_in),     // FSM 출력 연결
        .pwm_out(internal_motor_pwm_out), 
        .in1_in2(internal_in1_in2)
    );

    servo_motor_control u_servo_motor_control (
        .clk(clk), 
        .reset(reset), 
        .humidity(humidity), 
        .servo_pwm_out(servo_pwm_out_internal)
    );
    
    // 5. 핵심 제어 FSM 모듈
    aircondition_fsm u_aircondition_fsm (
        .clk(clk),
        .reset(reset),
        .w_btnU(w_btnU), .w_btnL(w_btnL), .w_btnC(w_btnC), .w_btnR(w_btnR), .w_btnD(w_btnD),
        .danger_close(danger_close),
        .motor_direction(motor_direction),
        .current_temp(temperature),
        .sw0(sw[0]),
        .o_display_mode(fsm_display_mode),
        .o_manual_value(fsm_manual_value),
        .o_dc_motor_direction(fsm_dc_motor_direction),
        .o_dc_motor_temp_in(fsm_dc_motor_temp_in),
        .o_servo_active(fsm_servo_active)
    );

    // --- 최종 출력 할당 ---
    // LED
    assign led[1:0]   = fsm_display_mode[1:0]; // FSM 모드 하위 2비트 표시
    assign led[3:2]   = fsm_dc_motor_direction;
    assign led[11]    = ultrasonic_done_pulse;
    assign led[12]    = dht11_done_pulse;
    assign led[10:4]  = 7'b0;
    assign led[14:13] = 2'b00;

    // DC 모터
    assign pwm_out = internal_motor_pwm_out;
    assign in1_in2 = internal_in1_in2;

    // 부저 (MUX)
    assign buzzer = danger_close ? warning_buzzer_signal : button_buzzer_signal;
    
    // 서보 모터 (FSM의 활성화 신호에 따라 출력 결정)
    assign servo_pwm_out = fsm_servo_active ? servo_pwm_out_internal : 1'bz;

endmodule