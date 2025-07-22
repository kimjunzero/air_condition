`timescale 1ns / 1ps

module main_top(
    // --- 시스템 공용 입출력 ---
    input clk,
    input reset,
    input btnU, btnL, btnC, btnR, btnD,
    input [7:0] sw,
    input RsRx,
    inout dht11_data,
    input ECHO,
    input [1:0] motor_direction,
    input door_switch,

    // always 블록에서 제어되므로 reg 타입으로 선언
    output reg RsTx,
    output reg TRIG,
    output reg [7:0] seg,
    output reg [3:0] an,
    output reg [14:0] led,
    output reg buzzer,
    output reg pwm_out,
    output reg [1:0] in1_in2,
    output reg servo_pwm_out
);

    localparam AIR_CONDITION = 2'b00, MINSEC_STOPWATCH = 2'b01, MICROWAVE = 2'b10;
    // --- 각 서브 시스템의 출력을 받을 내부 wire ---
    wire [7:0] aircon_seg, microwave_seg, stopwatch_seg;
    wire [3:0] aircon_an,  microwave_an,  stopwatch_an;
    wire [14:0] aircon_led, microwave_led, stopwatch_led;
    wire       aircon_buzzer, microwave_buzzer, minsec_stopwatch_buzzer;
    wire       aircon_pwm_out, microwave_pwm_out;
    wire [1:0] aircon_in1_in2, microwave_in1_in2;
    wire       aircon_servo_pwm_out, microwave_servo_pwm_out;
    wire       aircon_RsTx;
    wire       aircon_TRIG;
    
    // --- 1. 서브 시스템 모듈 인스턴스화 ---
    aircondition_mode u_aircondition_mode (
        .clk(clk), .reset(reset), .btnU(btnU), .btnL(btnL), .btnC(btnC), .btnR(btnR), .btnD(btnD),
        .sw(sw), .RsRx(RsRx), .dht11_data(dht11_data), .ECHO(ECHO),
        .motor_direction(motor_direction),
        .RsTx(aircon_RsTx), .TRIG(aircon_TRIG), .seg(aircon_seg), .an(aircon_an), .led(aircon_led), 
        .buzzer(aircon_buzzer), .pwm_out(aircon_pwm_out), .in1_in2(aircon_in1_in2), 
        .servo_pwm_out(aircon_servo_pwm_out)
    );

    microwave_mode u_microwave_mode (
        .clk(clk), .reset(reset), .btnU(btnU), .btnL(btnL), .btnC(btnC), .btnR(btnR), .btnD(btnD),
        .motor_direction(motor_direction),
        .door_switch(door_switch),
        .pwm_out(microwave_pwm_out), 
        .servo_pwm_out(microwave_servo_pwm_out),
        .in1_in2(microwave_in1_in2), .seg(microwave_seg), .an(microwave_an),
        .led(microwave_led), .buzzer(microwave_buzzer)
    );
    
    minsec_stopwatch_mode u_minsec_stopwatch_mode (
        .clk(clk), .reset(reset), .btnU(btnU), .btnL(btnL), .btnC(btnC), .btnR(btnR), .btnD(btnD),
        .sw(sw), 
        .seg(stopwatch_seg),
        .an(stopwatch_an),
        .led(stopwatch_led), .buzzer(minsec_stopwatch_buzzer)
    );

    // --- 2. 출력 MUX ---
    // sw[2:1] 값에 따라 어떤 시스템의 출력을 실제 하드웨어로 내보낼지 결정
    always @(*) begin
        case ({sw[1], sw[2]}) // 참고: 모드 선택 스위치가 sw[1], sw[2]로 설정됨
            MICROWAVE: begin // 전자레인지 모드
                seg = microwave_seg;
                an = microwave_an;
                led = microwave_led;
                buzzer = microwave_buzzer;
                pwm_out = microwave_pwm_out;
                in1_in2 = microwave_in1_in2;
                servo_pwm_out = microwave_servo_pwm_out;
                RsTx = 1'b1;
                TRIG = 1'b0;
            end
            MINSEC_STOPWATCH: begin // 스톱워치/시계 모드
                seg = stopwatch_seg;
                an = stopwatch_an;
                led = stopwatch_led;
                buzzer = minsec_stopwatch_buzzer;
                pwm_out = 1'b0;
                in1_in2 = 2'b00;
                servo_pwm_out = 1'b0;
                RsTx = 1'b1;
                TRIG = 1'b0;
            end
            default: begin // 스마트 공조기 모드 (기본)
                seg = aircon_seg;
                an = aircon_an;
                led = aircon_led;
                buzzer = aircon_buzzer;
                pwm_out = aircon_pwm_out;
                in1_in2 = aircon_in1_in2;
                servo_pwm_out = aircon_servo_pwm_out;
                RsTx = aircon_RsTx;
                TRIG = aircon_TRIG;
            end
        endcase
    end

endmodule
