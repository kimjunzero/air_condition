`timescale 1ns / 1ps

module minsec_stopwatch_mode(
    input clk,
    input reset,
    // btnD 입력 포트 추가
    input btnU, btnL, btnC, btnR, btnD,
    input [7:0] sw,     

    output [7:0] seg,
    output [3:0] an,
    output [14:0] led,
    // buzzer 출력 포트
    output buzzer
);

    // --- 내부 신호 ---
    // w_btnD 와이어 추가
    wire w_btnU, w_btnL, w_btnC, w_btnR, w_btnD; 
    wire [15:0] w_seg_bcd;

    // --- 모듈 인스턴스화 ---

    // 1. 5개의 버튼을 각각 디바운싱
    button_debounce u_btnU_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnU), .o_btn_clean(w_btnU));
    button_debounce u_btnL_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnL), .o_btn_clean(w_btnL));
    button_debounce u_btnC_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnC), .o_btn_clean(w_btnC));
    button_debounce u_btnR_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnR), .o_btn_clean(w_btnR));
    // btnD 디바운싱
    button_debounce u_btnD_debounce(.i_clk(clk), .i_reset(reset), .i_btn(btnD), .o_btn_clean(w_btnD));

    // 피에조 부저 모듈
    piezo_buzzer u_piezo_buzzer(
        .clk(clk), 
        .reset(reset), 
        .btnU(w_btnU), 
        .btnC(w_btnC), 
        .btnR(w_btnR), 
        .btnD(w_btnD), // 올바른 신호에 연결
        .btnL(w_btnL), 
        .buzzer(buzzer) // 모듈의 최종 buzzer 출력 포트에 직접 연결
    );
    
    // 2. 버튼 제어 FSM 모듈
    btn_command_controller u_btn_command_controller(
        .clk(clk),
        .reset(reset),
        .btnU(w_btnU),
        .btnL(w_btnL),
        .btnC(w_btnC),
        .btnR(w_btnR),
        .sw(sw),
        .seg_data(w_seg_bcd),
        .led(led)
    );

    // 3. FND 컨트롤러 모듈
    fnd_controller u_fnd_controller(
        .clk(clk),
        .reset(reset),
        .input_data(w_seg_bcd),
        .seg_data(seg),
        .an(an)
    );

endmodule
