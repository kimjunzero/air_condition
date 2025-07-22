`timescale 1ns / 1ps

// 시계와 스톱워치 시간 계산을 담당하는 핵심 모듈
module clock_stopwatch(
    input clk,
    input reset,             // FPGA 보드 전체 리셋
    input btnU,              // 모드 전체 초기화 버튼
    input btnL, btnC, btnR,  // 개별 버튼 입력
    input [7:0] sw,
    output [15:0] seg_bcd,
    output [14:0] led
);

    // --- 가독성을 위한 정의 ---
    localparam CLOCK_MODE     = 1'b0;
    localparam STOPWATCH_MODE = 1'b1;
    localparam SEC_COUNT      = 100_000_000;
    parameter  MS_COUNT       = 100_000;

    // --- 내부 레지스터 ---
    reg mode = CLOCK_MODE;
    reg [5:0] clock_minutes = 0, clock_seconds = 0;
    reg [5:0] sw_seconds = 0;
    reg [9:0] sw_ms = 0;
    reg [26:0] sec_counter = 0;
    reg [16:0] ms_counter = 0;
    reg stopwatch_running = 0, clock_running = 0;
    
    // --- 버튼 엣지 검출 ---
    wire [3:0] btn = {btnU, btnR, btnC, btnL};
    reg [3:0] btn_prev = 0;
    wire [3:0] btn_edge = btn & ~btn_prev;
    
    // --- 메인 로직 ---
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            // 하드웨어 리셋: 모든 상태를 완전 초기화
            mode <= CLOCK_MODE;
            {clock_minutes, clock_seconds} <= 0;
            {sw_seconds, sw_ms} <= 0;
            {sec_counter, ms_counter} <= 0;
            {stopwatch_running, clock_running} <= 0;
            btn_prev <= 0;
        end else begin
            btn_prev <= btn;

            // --- btnU (전체 초기화) ---
            if (btn_edge[3]) begin
                {clock_minutes, clock_seconds} <= 0;
                {sw_seconds, sw_ms} <= 0;
                {sec_counter, ms_counter} <= 0;
                {clock_running, stopwatch_running} <= 0;
            end
            
            // --- btnL (모드 변경) ---
            if (btn_edge[0]) begin
                mode <= ~mode;
            end
            
            // --- btnC (시작/정지) ---
            if (btn_edge[1]) begin
                if (mode == CLOCK_MODE) clock_running <= ~clock_running;
                else stopwatch_running <= ~stopwatch_running;
            end
            
            // --- btnR (현재 모드 초기화) ---
            if (btn_edge[2]) begin
                if (mode == CLOCK_MODE) {clock_minutes, clock_seconds, sec_counter} <= 0;
                else {sw_seconds, sw_ms, ms_counter, stopwatch_running} <= 0;
            end

            // --- 시간 증가 로직 ---
            if (clock_running) begin
                if (sec_counter >= SEC_COUNT - 1) begin
                    sec_counter <= 0;
                    if (clock_seconds == 59) begin
                        clock_seconds <= 0;
                        if (clock_minutes == 59) clock_minutes <= 0;
                        else clock_minutes <= clock_minutes + 1;
                    end else clock_seconds <= clock_seconds + 1;
                end else sec_counter <= sec_counter + 1;
            end

            if (mode == STOPWATCH_MODE && stopwatch_running) begin
                if (ms_counter >= MS_COUNT - 1) begin
                    ms_counter <= 0;
                    if (sw_ms == 999) begin
                        sw_ms <= 0;
                        if (sw_seconds == 59) sw_seconds <= 0;
                        else sw_seconds <= sw_seconds + 1;
                    end else sw_ms <= sw_ms + 1;
                end else ms_counter <= ms_counter + 1;
            end
        end
    end
    
    // --- 출력 데이터 생성 (BCD 포맷) ---
    wire [3:0] digit3 = (mode == CLOCK_MODE) ? clock_minutes / 10 : sw_seconds / 10;
    wire [3:0] digit2 = (mode == CLOCK_MODE) ? clock_minutes % 10 : sw_seconds % 10;
    wire [3:0] digit1 = (mode == CLOCK_MODE) ? clock_seconds / 10 : (sw_ms / 100);
    wire [3:0] digit0 = (mode == CLOCK_MODE) ? clock_seconds % 10 : (sw_ms / 10) % 10;
    assign seg_bcd = {digit3, digit2, digit1, digit0};
    
    // --- LED 출력 ---
    assign led[14] = (mode == STOPWATCH_MODE);
    assign led[13] = (mode == CLOCK_MODE) ? clock_running : stopwatch_running;
    assign led[12:0] = 13'b0;
    
endmodule
