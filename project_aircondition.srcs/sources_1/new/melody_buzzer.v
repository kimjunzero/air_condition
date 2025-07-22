`timescale 1ns / 1ps

// 시작 신호를 받으면 설정된 멜로디를 한 번 재생하는 모듈
module melody_buzzer (
    input clk,
    input reset,
    input i_play_start, // 멜로디 재생을 시작시키는 1클럭 펄스 신호
    output reg o_buzzer,
    output o_is_playing  // 멜로디가 재생 중인지 알려주는 상태 신호
);

    // --- 파라미터 ---
    parameter CLK_FREQ = 100_000_000;

    // 음계별 주파수 카운터 값 (값이 작을수록 높은 음)
    localparam NOTE_C4 = 191570; // 도
    localparam NOTE_E4 = 151975; // 미
    localparam NOTE_G4 = 127551; // 솔
    localparam NOTE_C5 = 95602;  // 높은 도
    localparam SILENT  = 0;

    // 음 길이 (ms)
    localparam DURATION_NOTE = CLK_FREQ / 1000 * 150; // 150ms
    localparam DURATION_PAUSE = CLK_FREQ / 1000 * 50;  // 50ms

    // --- FSM 상태 정의 ---
    localparam [3:0] S_IDLE = 0,
                     S_PLAY1 = 1, S_PAUSE1 = 2,
                     S_PLAY2 = 3, S_PAUSE2 = 4,
                     S_PLAY3 = 5, S_PAUSE3 = 6,
                     S_PLAY4 = 7;

    // --- 내부 레지스터 ---
    reg [3:0] state = S_IDLE;
    reg [27:0] duration_cnt = 0;
    reg [17:0] freq_cnt = 0;
    reg [17:0] freq_period = 0;

    assign o_is_playing = (state != S_IDLE);

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            duration_cnt <= 0;
            freq_cnt <= 0;
            freq_period <= SILENT;
            o_buzzer <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (i_play_start) begin
                        duration_cnt <= DURATION_NOTE;
                        freq_period <= NOTE_C4;
                        state <= S_PLAY1;
                    end
                end
                S_PLAY1: begin
                    if (duration_cnt == 0) {duration_cnt, freq_period, state} <= {DURATION_PAUSE, SILENT, S_PAUSE1};
                    else duration_cnt <= duration_cnt - 1;
                end
                S_PAUSE1: begin
                    if (duration_cnt == 0) {duration_cnt, freq_period, state} <= {DURATION_NOTE, NOTE_E4, S_PLAY2};
                    else duration_cnt <= duration_cnt - 1;
                end
                S_PLAY2: begin
                    if (duration_cnt == 0) {duration_cnt, freq_period, state} <= {DURATION_PAUSE, SILENT, S_PAUSE2};
                    else duration_cnt <= duration_cnt - 1;
                end
                S_PAUSE2: begin
                    if (duration_cnt == 0) {duration_cnt, freq_period, state} <= {DURATION_NOTE, NOTE_G4, S_PLAY3};
                    else duration_cnt <= duration_cnt - 1;
                end
                S_PLAY3: begin
                    if (duration_cnt == 0) {duration_cnt, freq_period, state} <= {DURATION_PAUSE, SILENT, S_PAUSE3};
                    else duration_cnt <= duration_cnt - 1;
                end
                S_PAUSE3: begin
                    if (duration_cnt == 0) {duration_cnt, freq_period, state} <= {DURATION_NOTE, NOTE_C5, S_PLAY4};
                    else duration_cnt <= duration_cnt - 1;
                end
                S_PLAY4: begin
                    if (duration_cnt == 0) {duration_cnt, freq_period, state} <= {0, SILENT, S_IDLE};
                    else duration_cnt <= duration_cnt - 1;
                end
            endcase

            // 주파수 생성 로직
            if (freq_period != SILENT) begin
                if (freq_cnt >= freq_period - 1) begin
                    freq_cnt <= 0;
                    o_buzzer <= ~o_buzzer;
                end else begin
                    freq_cnt <= freq_cnt + 1;
                end
            end else begin
                o_buzzer <= 1'b0;
            end
        end
    end

endmodule
