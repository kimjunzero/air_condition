`timescale 1ns / 1ps

// Module: warning_buzzer
// Function: 입력 신호(danger_close)가 1일 때, 1kHz의 경고음을 발생시킴
module warning_buzzer (
    input clk,          // 100MHz 시스템 클럭
    input reset,        // Active-high 리셋
    input danger_close, // 이 신호가 1일 때 부저가 활성화됨
    output reg buzzer_out
);

    // 1kHz 주파수를 만들기 위한 카운터 (100MHz / (2 * 1kHz) = 50000)
    parameter BEEP_PERIOD = 50000; 
    reg [15:0] counter = 0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            buzzer_out <= 1'b0;
        end 
        // danger_close 신호가 활성화되었을 때만 동작
        else if (danger_close) begin 
            if (counter >= BEEP_PERIOD - 1) begin
                counter <= 0;
                buzzer_out <= ~buzzer_out; // 부저 출력 신호 토글
            end else begin
                counter <= counter + 1;
            end
        end 
        // 위험 상황이 아닐 때는 부저를 끄고 카운터를 리셋
        else begin 
            counter <= 0;
            buzzer_out <= 1'b0;
        end
    end

endmodule