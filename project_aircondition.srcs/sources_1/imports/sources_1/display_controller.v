`timescale 1ns / 1ps

module display_controller(
    input clk,
    input reset,
    
    // 표시할 데이터 소스
    input [7:0] temperature,
    input [7:0] humidity,
    input [7:0] distance,
    input [7:0] manual_value, // FSM으로부터 목표온도, 팬속도 등을 전달받음

    // FSM으로부터 전달받는 표시 모드
    input [2:0] display_mode,

    output reg [7:0] seg,
    output reg [3:0] an
);
    
    // --- FSM으로부터 전달받는 표시 모드 정의 ---
    localparam DISP_AUTO      = 3'd0; // 온/습도 자동 표시
    localparam DISP_DIST      = 3'd1; // 거리 표시
    localparam DISP_MANUAL    = 3'd2; // (예비) 수동 데이터 표시
    localparam DISP_TARGET    = 3'd3; // 목표 온도 표시
    localparam DISP_FAN_LEVEL = 3'd4; // 팬 레벨 표시
    localparam DISP_TIMER     = 3'd5; // 타이머 표시
    localparam DISP_OFF       = 3'd6; // 꺼짐

    // --- 내부 신호 ---
    reg [19:0] clk_div_cnt;
    reg [1:0]  digit_select;
    reg [4:0]  number_to_display;

    // --- BCD 변환 ---
    // 공통으로 사용할 BCD 변환 로직
    reg  [7:0] bcd_input;
    wire [3:0] bcd_hundreds = bcd_input / 100;
    wire [3:0] bcd_tens     = (bcd_input % 100) / 10;
    wire [3:0] bcd_ones     = bcd_input % 10;

    // --- 클럭 분주 로직 ---
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_div_cnt  <= 0;
            digit_select <= 0;
        end else begin
            if (clk_div_cnt == 50000) begin 
                clk_div_cnt  <= 0;
                digit_select <= digit_select + 1;
            end else begin
                clk_div_cnt <= clk_div_cnt + 1;
            end
        end
    end

    // --- 핵심 로직: display_mode에 따라 FND 출력 결정 ---
    always @(*) begin
        // 기본값 설정
        an = 4'b1111;
        number_to_display = 15; // Blank
        bcd_input = 0;

        case(display_mode)
            DISP_AUTO: begin
                case(digit_select)
                    2'b00: begin an=4'b1110; number_to_display=humidity % 10; end       // 습도 1의 자리
                    2'b01: begin an=4'b1101; number_to_display=humidity / 10; end       // 습도 10의 자리
                    2'b10: begin an=4'b1011; number_to_display=temperature % 10; end    // 온도 1의 자리
                    2'b11: begin an=4'b0111; number_to_display=temperature / 10; end    // 온도 10의 자리
                endcase
            end
            DISP_DIST: begin
                bcd_input = distance;
                case(digit_select)
                    2'b00: begin an=4'b1110; number_to_display=bcd_ones; end
                    2'b01: begin an=4'b1101; number_to_display=bcd_tens; end
                    2'b10: begin an=4'b1011; number_to_display=bcd_hundreds; end
                    2'b11: begin an=4'b0111; number_to_display=13; end // 'd'
                endcase
            end
            DISP_TARGET: begin
                bcd_input = manual_value;
                case(digit_select)
                    2'b00: begin an=4'b1110; number_to_display=bcd_ones; end
                    2'b01: begin an=4'b1101; number_to_display=bcd_tens; end
                    2'b10: begin an=4'b1011; number_to_display=15; end // Blank
                    2'b11: begin an=4'b0111; number_to_display=11; end // 't'
                endcase
            end
            DISP_FAN_LEVEL: begin
                bcd_input = manual_value;
                case(digit_select)
                    2'b00: begin an=4'b1110; number_to_display=bcd_ones; end
                    2'b01: begin an=4'b1101; number_to_display=15; end // Blank
                    2'b10: begin an=4'b1011; number_to_display=15; end // Blank
                    2'b11: begin an=4'b0111; number_to_display=10; end // 'F'
                endcase
            end
            DISP_TIMER: begin
                bcd_input = manual_value;
                case(digit_select)
                    2'b00: begin an=4'b1110; number_to_display=bcd_ones; end
                    2'b01: begin an=4'b1101; number_to_display=bcd_tens; end
                    2'b10: begin an=4'b1011; number_to_display=bcd_hundreds; end
                    2'b11: begin an=4'b0111; number_to_display=14; end // 'H'
                endcase
            end
            DISP_OFF: begin
                // 모든 자리에 '-' 표시
                number_to_display = 16; // '_'
                case(digit_select)
                    2'b00: begin an=4'b1110; number_to_display=16; end // E
                    2'b01: begin an=4'b1101; number_to_display=17; end // L
                    2'b10: begin an=4'b1011; number_to_display=13; end // d
                    2'b11: begin an=4'b0111; number_to_display=1; end // I
                endcase
            end
            default: begin
                an = 4'b1111;
                number_to_display = 15; // Blank
            end
        endcase
    end

    // --- 4비트 숫자/문자 -> 7세그먼트 패턴 변환 ---
    always @(*) begin
        case(number_to_display)
            5'd0:  seg = 8'b11000000; // 0
            5'd1:  seg = 8'b11111001; // 1
            5'd2:  seg = 8'b10100100; // 2
            5'd3:  seg = 8'b10110000; // 3
            5'd4:  seg = 8'b10011001; // 4
            5'd5:  seg = 8'b10010010; // 5
            5'd6:  seg = 8'b10000010; // 6
            5'd7:  seg = 8'b11111000; // 7
            5'd8:  seg = 8'b10000000; // 8
            5'd9:  seg = 8'b10010000; // 9
            5'd10: seg = 8'b10001110; // F
            5'd11: seg = 8'b10000111; // t
            5'd12: seg = 8'b10010010; // S
            5'd13: seg = 8'b10100001; // d
            5'd14: seg = 8'b10001001; // H
            5'd15: seg = 8'b11110111; // _
            5'd16: seg = 8'b10000110; // E
            5'd17: seg = 8'b11000111; // L
            default: seg = 8'b11111111; // All OFF (Blank)
        endcase
    end

endmodule