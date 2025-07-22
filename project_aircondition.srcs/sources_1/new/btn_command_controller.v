`timescale 1ns / 1ps

module btn_command_controller(
    input clk,
    input reset,       // 시스템 전체 리셋
    input btnU,        // ◀◀ 추가: 초기화 버튼
    input btnL, btnC, btnR, // 개별 버튼
    input [7:0] sw,
    output [15:0] seg_data,
    output [14:0] led
);

    // --- clock_stopwatch 모듈을 직접 호출 ---
    clock_stopwatch u_clock_stopwatch(
        .clk(clk),
        .reset(reset), // 시스템 리셋 전달
        .btnU(btnU),   // btnU 신호 전달
        .btnL(btnL),
        .btnC(btnC),
        .btnR(btnR),
        .sw(sw),
        .seg_bcd(seg_data), // 출력을 바로 상위로 전달
        .led(led)           // 출력을 바로 상위로 전달
    );

endmodule
