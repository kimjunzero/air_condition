`timescale 1ns / 1ps

// 틱 생성기 모듈
// 기능: 100MHz 입력 클럭에서 1kHz 틱 펄스 신호를 생성
// 방식: 펄스 방식 (토클 방식과 다름 - 1클럭만 High)
// 용도: 타이머, 카운터, 주기적 이벤트 생성 등
module tick_generator # (
    parameter integer INPUT_FREQ = 100_000_000, // 입력 클럭 주파수 (100MHz)
    parameter integer TICK_HZ = 1000           // 목표 틱 주파수 (1kHz) -> 1ms
) (
    input wire clk,
    input wire reset,
    output reg tick
);

    // 틱 생성 주기 계산
    // 1kHz = 1000번/초 -> 1번당 1ms 간경
    // 100MHz에서 1ms = 100,000,000 / 1000 = 100,00 클럭
    parameter TICK_COUNT = INPUT_FREQ / TICK_HZ;  // 100,000 클럭

    // 틱 생성용 카운터
    reg [$clog2(TICK_COUNT)-1:0] r_tick_counter = 0;    // 17비트 카운터

    // 메인 로직: 틱 펄스 생성
    always @(posedge clk, posedge reset) begin

        // 비동기 리셋 처리
        if (reset) begin
            r_tick_counter <= 0;
            tick <= 0;
        end 
        
        // 정상 틱 생성 동작
        else begin
            // 카운터가 목표값에 도달했는지 확인
            if (r_tick_counter == TICK_COUNT-1) begin // 99,999에 도달
                // 틱 생성 시점 도달
                r_tick_counter <= 0;    // 카운터 리셋
                tick <= 1'b1;           // 틱 펄스 생성 (1클럭 동안 High)
            end 
            else begin
                // 아직 틱 생성 시점 아님
                r_tick_counter <= r_tick_counter + 1;   // 카운터 계속 증가
                tick <= 1'b0;                           // 틱 출력 Low 유지
            end
        end
    end
endmodule
