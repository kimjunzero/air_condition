`timescale 1ns / 1ps

// 새로운 멜로디 버저 모듈
module piezo_buzzer (
    input clk,
    input reset,
    input btnU, btnC, btnR, btnD, btnL, // 5개의 모든 버튼을 입력으로 받음
    output buzzer
);

    // --- 파라미터 ---
    parameter CLK_FREQ      = 100_000_000;
    parameter TIME_70MS     = CLK_FREQ / 1000 * 70;
    parameter TIME_3S       = CLK_FREQ * 3;
    
    // 멜로디 음계 (POWER_ON 모드)
    parameter F_1KHZ        = 50000, F_2KHZ = 25000, 
              F_3KHZ        = 16666, F_4KHZ = 12500;
    parameter SILENT        = 0;

    // --- 상태 머신 정의 ---
    parameter MODE_IDLE       = 1'b0, 
              MODE_PLAY_MELODY = 1'b1;

    // --- 내부 신호 선언 ---
    wire any_button_pressed;
    wire any_btn_posedge;
    wire w_duration_done;

    reg  any_btn_prev;
    reg  play_melody_en; // 멜로디를 한 번만 재생하기 위한 트리거

    reg  mode;
    reg  [2:0] step; // 멜로디의 현재 재생 단계

    reg  [28:0] duration_cnt;
    reg  [28:0] duration_limit;

    reg  [17:0] sound_set;
    reg  [17:0] freq_cnt;
    reg  buzzer_toggle;

    // 1. 5개 버튼 중 하나라도 눌렸는지 확인
    assign any_button_pressed = btnU | btnC | btnR | btnD | btnL;

    // 2. 버튼이 눌리는 순간을 감지 (Rising Edge Detection)
    always @(posedge clk) begin
        any_btn_prev <= any_button_pressed;
    end
    assign any_btn_posedge = any_button_pressed & ~any_btn_prev;

    // 3. 멜로디 재생 트리거 (One-shot)
    // 버튼이 눌리면 play_melody_en을 1로 만들고, 멜로디가 끝나면 0으로 리셋
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            play_melody_en <= 1'b0;
        end else if (step == 4 && w_duration_done) begin // 멜로디가 끝나면
            play_melody_en <= 1'b0;
        end else if (any_btn_posedge) begin // 버튼이 새로 눌리면
            play_melody_en <= 1'b1;
        end
    end

    // 4. 멜로디 재생을 제어하는 FSM (Finite State Machine)
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            mode <= MODE_IDLE;
            step <= 0;
        end else begin
            // 모드 결정: 트리거가 켜지면 재생 모드로, 아니면 대기 모드
            if (play_melody_en) begin
                mode <= MODE_PLAY_MELODY;
            end else begin
                mode <= MODE_IDLE;
            end

            // 재생 단계(step) 업데이트: 한 음의 재생이 끝나면 다음 단계로
            if (mode == MODE_IDLE) begin
                step <= 0;
            end else if (w_duration_done && step < 4) begin
                step <= step + 1;
            end
        end
    end

    // 5. 현재 단계에 맞는 음계와 길이를 선택
    always @(*) begin
        case (mode)
            MODE_PLAY_MELODY: begin
                duration_limit = (step == 4) ? TIME_3S : TIME_70MS;
                case (step)
                    0:       sound_set = F_1KHZ;
                    1:       sound_set = F_2KHZ;
                    2:       sound_set = F_3KHZ;
                    3:       sound_set = F_4KHZ;
                    4:       sound_set = SILENT; // 마지막은 긴 침묵
                    default: sound_set = SILENT;
                endcase
            end
            default: begin // MODE_IDLE
                sound_set      = SILENT;
                duration_limit = 0;
            end
        endcase
    end

    // 6. 각 음의 길이를 세는 카운터
    assign w_duration_done = (duration_cnt == 0);
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            duration_cnt <= 0;
        end else if (mode == MODE_IDLE) begin
            duration_cnt <= 0;
        end else if (w_duration_done) begin
            duration_cnt <= duration_limit - 1; // 다음 음의 길이로 카운터 설정
        end else if (duration_cnt != 0) begin
            duration_cnt <= duration_cnt - 1;
        end
    end
    
    // 7. 주파수를 생성하여 버저를 토글시키는 로직
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            freq_cnt      <= 0;
            buzzer_toggle <= 1'b0;
        end else if (w_duration_done) begin
            freq_cnt      <= 0;
            buzzer_toggle <= 1'b0;
        end else if (sound_set == SILENT) begin
            freq_cnt      <= 0;
            buzzer_toggle <= 1'b0;
        end else if (freq_cnt >= sound_set - 1) begin
            freq_cnt      <= 0;
            buzzer_toggle <= ~buzzer_toggle;
        end else begin
            freq_cnt      <= freq_cnt + 1;
        end
    end

    // 8. 최종 버저 출력
    assign buzzer = buzzer_toggle;

endmodule