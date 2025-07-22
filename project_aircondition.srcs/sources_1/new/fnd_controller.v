`timescale 1ns / 1ps

// ===== 최상위 FND 컨트롤러 모듈 =====
// 14비트 이진 데이터를 받아서 4자리 7-segment 디스플레이에 표시
module fnd_controller(
    input clk,                  // 100MHz 시스템 클럭
    input reset,                // 리셋 신호
    input [15:0] input_data,    // 표시할 데이터 (0~9999)
    output [7:0] seg_data,      // 7-segment 패턴 출력 (a~g + dp)
    output [3:0] an             // 자릿수 선택 신호 (4개 디스플레이 중 1개씩 켜기)
    );

    // ===== 내부 연결 와이어 =====
    wire [1:0] w_sel;           // 현재 선택된 자릿수 (00, 01, 10, 11)
    wire [3:0] w_d1, w_d10, w_d100, w_d1000;  // 각 자릿수의 BCD 값 (0~9)
 
    // ===== 자릿수 선택 모듈 =====
    // 1ms마다 4개 자릿수를 순환하면서 선택
    fnd_digit_select u_fnd_digit_select(
        .clk(clk),
        .reset(reset),
        .sel(w_sel)             // 현재 선택된 자릿수 출력
    );

    // ===== 이진수 → BCD 변환 모듈 =====
    // 14비트 이진수를 4자리 BCD로 분리
    bin2bcd u_bin2bcd(
        .in_data(input_data),   // 입력: 14비트 이진수
        .d1(w_d1),              // 출력: 1의 자리
        .d10(w_d10),            // 출력: 10의 자리
        .d100(w_d100),          // 출력: 100의 자리
        .d1000(w_d1000)         // 출력: 1000의 자리
    );

    // ===== 7-segment 디스플레이 제어 모듈 =====
    // BCD 데이터를 7-segment 패턴으로 변환하고 자릿수 선택
    fnd_display u_fnd_display(
        .digit_sel(w_sel),      // 현재 선택된 자릿수
        .d1(w_d1),              // 1의 자리 BCD
        .d10(w_d10),            // 10의 자리 BCD
        .d100(w_d100),          // 100의 자리 BCD
        .d1000(w_d1000),        // 1000의 자리 BCD
        .an(an),                // 자릿수 선택 출력
        .seg(seg_data)          // 7-segment 패턴 출력
    );
endmodule

// ===== 자릿수 선택 모듈 =====
// 1ms마다 4개 자릿수를 순환하면서 선택 (멀티플렉싱)
// 빠른 속도로 각 자릿수를 순서대로 켜서 전체가 켜진 것처럼 보이게 함
module fnd_digit_select(
    input clk,                  // 100MHz 클럭
    input reset,                // 리셋 신호
    output reg [1:0] sel        // 선택된 자릿수 (00, 01, 10, 11)
    );

    reg [16:0] r_1ms_counter = 0;   // 1ms 카운터 (100,000 클럭)
    reg [1:0] r_digit_sel = 0;      // 내부 자릿수 선택 신호
    
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            r_1ms_counter <= 0;
            r_digit_sel <= 0;
            sel <= 0;
        end else begin
            // 1ms가 지나면 다음 자릿수로 이동
            if (r_1ms_counter == 100_000 - 1) begin // 1ms (100MHz 기준)
                r_1ms_counter <= 0;
                r_digit_sel <= r_digit_sel + 1;    // 00 → 01 → 10 → 11 → 00...
                sel <= r_digit_sel;
            end else begin
                r_1ms_counter <= r_1ms_counter + 1;
            end
        end
    end
endmodule

// ===== 이진수 → BCD 변환 모듈 =====
// 14비트 이진수(0~16383)를 4자리 BCD로 변환
// 실제로는 0~9999만 사용 (4자리 숫자 표현)
module bin2bcd(
    input [13:0] in_data,       // 입력: 14비트 이진수
    output [3:0] d1,            // 출력: 1의 자리 (0~9)
    output [3:0] d10,           // 출력: 10의 자리 (0~9)
    output [3:0] d100,          // 출력: 100의 자리 (0~9)
    output [3:0] d1000          // 출력: 1000의 자리 (0~9)
);
    // 각 자릿수 추출 (나머지 연산 사용)
    assign d1 = in_data % 10;           // 1의 자리: 입력 % 10
    assign d10 = (in_data / 10) % 10;   // 10의 자리: (입력 / 10) % 10
    assign d100 = (in_data / 100) % 10; // 100의 자리: (입력 / 100) % 10
    assign d1000 = (in_data / 1000) % 10; // 1000의 자리: (입력 / 1000) % 10

endmodule

// ===== 7-segment 디스플레이 제어 모듈 =====
// BCD 데이터를 실제 7-segment 패턴으로 변환하고 자릿수 선택
module fnd_display(
    input [1:0] digit_sel,      // 현재 선택된 자릿수
    input [3:0] d1,             // 1의 자리 BCD
    input [3:0] d10,            // 10의 자리 BCD
    input [3:0] d100,           // 100의 자리 BCD
    input [3:0] d1000,          // 1000의 자리 BCD
    output reg [3:0] an,        // 자릿수 선택 출력 (0=켜짐, 1=꺼짐)
    output reg [7:0] seg        // 7-segment 패턴 (0=켜짐, 1=꺼짐)
);

    reg [3:0] bcd_data;         // 현재 표시할 BCD 데이터

    // ===== 자릿수 선택 및 데이터 선택 =====
    always @(*) begin
        case (digit_sel)
            2'b00: begin bcd_data = d1; an = 4'b1110; end      // 1의 자리 선택
            2'b01: begin bcd_data = d10; an = 4'b1101; end     // 10의 자리 선택
            2'b10: begin bcd_data = d100; an = 4'b1011; end    // 100의 자리 선택
            2'b11: begin bcd_data = d1000; an = 4'b0111; end   // 1000의 자리 선택
            default: begin bcd_data = 4'b0000; an = 4'b1111; end // 모두 꺼짐
        endcase
    end

    // ===== BCD → 7-segment 패턴 변환 =====
    // 각 숫자에 대응하는 7-segment 패턴 (Common Anode 방식)
    always @(*) begin
        case (bcd_data)
            4'd0: seg = 8'b11000000;    // 0: abcdef 켜짐
            4'd1: seg = 8'b11111001;    // 1: bc 켜짐
            4'd2: seg = 8'b10100100;    // 2: abdeg 켜짐
            4'd3: seg = 8'b10110000;    // 3: abcdg 켜짐
            4'd4: seg = 8'b10011001;    // 4: bcfg 켜짐
            4'd5: seg = 8'b10010010;    // 5: acdfg 켜짐
            4'd6: seg = 8'b10000010;    // 6: acdefg 켜짐
            4'd7: seg = 8'b11111000;    // 7: abc 켜짐
            4'd8: seg = 8'b10000000;    // 8: abcdefg 켜짐
            4'd9: seg = 8'b10010000;    // 9: abcdfg 켜짐
            default: seg = 8'b11111111; // 모든 세그먼트 꺼짐
        endcase
    end
endmodule
