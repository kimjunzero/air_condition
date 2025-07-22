`timescale 1ns / 1ps

module microwave_mode (
    // 입력 port
    input clk, reset,
    input btnU, btnL, btnD, btnC, btnR,
    input [1:0] motor_direction,
    input door_switch,

    // 출력 port
    output pwm_out,
    output servo_pwm_out,
    output [1:0]  in1_in2,
    output [7:0]  seg,
    output [3:0]  an,
    output [14:0] led,
    output        buzzer
);
    
    // --- Wires ---
    wire w_btnU, w_btnL, w_btnD, w_btnC, w_btnR;
    wire [7:0] w_anim_seg;
    wire [3:0] w_anim_an;

    // FSM signals
    wire [15:0] w_time_display;
    wire        w_finished_blink;
    wire        w_show_animation;
    wire        w_fnd_blink;
    wire        w_motor_on;
    wire        w_servo_active;
    wire        w_melody_start;      // ◀◀ 추가: 멜로디 시작 신호
    
    // Buzzer signals for MUX
    wire        melody_is_playing;   // ◀◀ 추가: 멜로디 재생 상태
    wire        button_buzzer_sound; // ◀◀ 추가: 버튼음 전용선
    wire        melody_buzzer_sound; // ◀◀ 추가: 멜로디음 전용선

    // PWM & Servo signals
    wire        w_raw_pwm_out;
    wire [3:0]  w_DUTY_CYCLE;
    wire        servo_pwm_out_internal;

    // FND signals
    wire [7:0] fnd_seg_data;
    wire [3:0] fnd_an_data;

    //--- Module Instantiations ---

    button_debounce u_btnU_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnU), .o_btn_clean(w_btnU));
    button_debounce u_btnC_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnC), .o_btn_clean(w_btnC));
    button_debounce u_btnR_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnR), .o_btn_clean(w_btnR));
    button_debounce u_btnD_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnD), .o_btn_clean(w_btnD));
    button_debounce u_btnL_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnL), .o_btn_clean(w_btnL));

    microwave_fsm u_microwave_fsm (
        .clk(clk), .reset(reset),
        .i_btnU(w_btnU), .i_btnL(w_btnL), .i_btnC(w_btnC), .i_btnR(w_btnR), .i_btnD(w_btnD),
        .i_door_switch(door_switch),
        .o_time_display(w_time_display),
        .o_finished_blink(w_finished_blink),
        .o_fnd_blink(w_fnd_blink),
        .o_show_animation(w_show_animation),
        .o_motor_on(w_motor_on),
        .o_servo_active(w_servo_active),
        .o_melody_start(w_melody_start) // ◀◀ 추가: FSM의 멜로디 시작 신호 받기
    );

    microwave_pwm_motor_control u_microwave_pwm_motor_control (.clk(clk), .DUTY_CYCLE(w_DUTY_CYCLE), .pwm_out(w_raw_pwm_out));
    microwave_servo_control u_microwave_servo_control(.clk(clk), .reset(reset), .door_switch(door_switch), .servo_pwm_out(servo_pwm_out_internal));
    fnd_controller u_fnd_controller (.clk(clk), .reset(reset), .input_data(w_time_display), .seg_data(fnd_seg_data), .an(fnd_an_data));
    fnd_animation u_fnd_animation (.clk(clk), .reset(reset), .seg(w_anim_seg), .an(w_anim_an));
    
    // ◀◀ 수정: 2개의 부저 모듈 인스턴스화
    piezo_buzzer u_piezo_buzzer(
        .clk(clk), .reset(reset), 
        .btnU(w_btnU), .btnC(w_btnC), .btnR(w_btnR), .btnD(w_btnD), .btnL(w_btnL), 
        .buzzer(button_buzzer_sound) // 버튼음 전용선에 연결
    );
    
    melody_buzzer u_melody_buzzer(
        .clk(clk), .reset(reset), 
        .i_play_start(w_melody_start), 
        .o_buzzer(melody_buzzer_sound), // 멜로디음 전용선에 연결
        .o_is_playing(melody_is_playing)
    );
    
    // --- 최종 출력 할당 ---
    
    // LED logic
    assign led[0] = (w_time_display > 0);
    assign led[1] = w_finished_blink;
    assign led[3] = door_switch;
    assign led[4] = ~door_switch;
    
    // FND logic
    assign seg = w_show_animation ? w_anim_seg : fnd_seg_data;
    assign an  = w_show_animation ? w_anim_an  : (w_fnd_blink ? 4'b1111 : fnd_an_data);

    // Motor control logic
    assign pwm_out = w_motor_on;
    assign in1_in2 = motor_direction;
    
    // Servo motor logic
    assign servo_pwm_out = w_servo_active ? servo_pwm_out_internal : 1'bz;
    
    // ◀◀ 추가: 부저 MUX 로직
    // 멜로디가 재생 중일 때는 멜로디 소리를, 아닐 때는 버튼 소리를 최종 출력으로 선택
    assign buzzer = melody_is_playing ? melody_buzzer_sound : button_buzzer_sound;
    
endmodule
