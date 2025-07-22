`timescale 1ns / 1ps

module aircondition_mode_tb;

    // --- 입력 포트 ---
    reg clk;
    reg reset;
    reg btnU, btnL, btnC, btnR, btnD;
    reg [7:0] sw;
    reg RsRx;
    wire RsTx;

    // 센서
    wire dht11_data; // inout 이지만 여기선 wire로 처리 (내부에서 드라이브한다고 가정)
    reg ECHO;
    wire TRIG;

    // 디스플레이 및 출력
    wire [7:0] seg;
    wire [3:0] an;
    wire [14:0] led;
    wire buzzer;

    // 모터 제어
    reg [1:0] motor_direction;
    wire pwm_out;
    wire [1:0] in1_in2;

    // 서보 모터
    wire servo_pwm_out;

    // --- 인스턴스화 ---
    aircondition_mode uut (
        .clk(clk),
        .reset(reset),
        .btnU(btnU),
        .btnL(btnL),
        .btnC(btnC),
        .btnR(btnR),
        .btnD(btnD),
        .sw(sw),
        .RsRx(RsRx),
        .RsTx(RsTx),
        .dht11_data(dht11_data),
        .ECHO(ECHO),
        .TRIG(TRIG),
        .seg(seg),
        .an(an),
        .led(led),
        .buzzer(buzzer),
        .motor_direction(motor_direction),
        .pwm_out(pwm_out),
        .in1_in2(in1_in2),
        .servo_pwm_out(servo_pwm_out)
    );

    // --- 클럭 생성 ---
    initial clk = 0;
    always #5 clk = ~clk;  // 100MHz → 10ns 주기

    // --- 테스트 시나리오 ---
    initial begin
        $display("Simulation Start");
        // 초기값 설정
        reset = 1;
        btnU = 0; btnL = 0; btnC = 0; btnR = 0; btnD = 0;
        sw = 8'b0;
        RsRx = 1;
        ECHO = 0;
        motor_direction = 2'b00;

        // 리셋 유지 후 해제
        #200;
        reset = 0;
        #200;

        // 수동 모드 진입 (sw[0] = 1)
        sw[0] = 1;
        #100;

        // === 버튼 U 입력 시뮬레이션 (디바운싱 고려하여 100ms 유지) ===
        $display("Button U pressed");
        btnU = 1;
        #100_000_000; // 100ms
        btnU = 0;
        #100_000_000; // 이후 안정화 시간

        // === 버튼 C 입력 ===
        $display("Button C pressed");
        btnC = 1;
        #100_000_000;
        btnC = 0;
        #100_000_000;

        // === 초음파 시뮬레이션 ===
        // ECHO 신호 길이를 통해 거리 측정: 5cm ≈ 290us
        // 5cm 왕복 시간 계산: 5cm / (340m/s) = 약 294us
        $display("Ultrasonic echo signal (5cm)");
        ECHO = 1;
        #300_000;  // 300us
        ECHO = 0;
        #100_000_000;

        // === 버튼 D 입력 ===
        $display("Button D pressed");
        btnD = 1;
        #100_000_000;
        btnD = 0;
        #100_000_000;

        // === 버튼 R 입력 ===
        $display("Button R pressed");
        btnR = 1;
        #100_000_000;
        btnR = 0;
        #100_000_000;

        // === 버튼 L 입력 ===
        $display("Button L pressed");
        btnL = 1;
        #100_000_000;
        btnL = 0;
        #100_000_000;

        // === 모터 방향 수동 테스트 ===
        $display("Motor direction change");
        motor_direction = 2'b10;
        #200_000_000;

        $display("Simulation End");
        $stop;
    end

endmodule
