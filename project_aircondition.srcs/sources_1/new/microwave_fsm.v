`timescale 1ns / 1ps

module microwave_fsm #(parameter CLK_FREQ = 100_000_000)(
    input   clk,
    input   reset,
    input   i_btnU, i_btnL, i_btnC, i_btnR, i_btnD,
    input   i_door_switch,

    output reg [15:0] o_time_display,
    output reg        o_finished_blink,
    output reg        o_fnd_blink,
    output reg        o_show_animation,
    output reg        o_motor_on,
    output reg        o_servo_active,
    output reg        o_melody_start // ◀◀ 추가된 포트
);

    // --- 상태 정의 ---
    localparam [2:0] 
        S_IDLE     = 3'b000, S_TIME_SET = 3'b001,
        S_COOKING  = 3'b010, S_FINISHED = 3'b011,
        S_PAUSED   = 3'b100;

    // --- 내부 신호 ---
    reg [2:0]  state_reg, state_next;
    reg [15:0] time_reg;

    reg [$clog2(CLK_FREQ)-1:0] sec_counter;
    wire sec_tick;
    reg [3:0] finish_10s_counter;
    
    reg [$clog2(CLK_FREQ/2)-1:0] blink_counter;
    wire blink_on;

    reg [3:0] display_toggle_counter;

    reg p_btnU, p_btnL, p_btnC, p_btnR, p_btnD;
    wire btnU_edge, btnL_edge, btnC_edge, btnR_edge, btnD_edge;

    // --- 로직 ---

    // 버튼 엣지 검출
    assign btnU_edge = i_btnU & ~p_btnU; assign btnL_edge = i_btnL & ~p_btnL;
    assign btnC_edge = i_btnC & ~p_btnC; assign btnR_edge = i_btnR & ~p_btnR;
    assign btnD_edge = i_btnD & ~p_btnD;
    always @(posedge clk, posedge reset) {p_btnU, p_btnL, p_btnC, p_btnR, p_btnD} <= reset ? 5'b0 : {i_btnU, i_btnL, i_btnC, i_btnR, i_btnD};
    
    // 1초 타이머
    assign sec_tick = (sec_counter == CLK_FREQ - 1);
    always @(posedge clk) sec_counter <= sec_tick ? 0 : sec_counter + 1;
    
    // 0.5초 깜빡임 신호
    assign blink_on = (blink_counter < CLK_FREQ / 2);
    always @(posedge clk) blink_counter <= (blink_counter == CLK_FREQ-1) ? 0 : blink_counter + 1;

    // FSM 상태 레지스터
    always @(posedge clk, posedge reset) state_reg <= reset ? S_IDLE : state_next;

    // FSM 다음 상태 결정 로직
    always @(*) begin
        state_next = state_reg;
        case (state_reg)
            S_IDLE:     if (btnL_edge || btnC_edge || btnR_edge) state_next = S_TIME_SET;
            S_TIME_SET: if (btnD_edge && time_reg > 0) state_next = S_COOKING;
                        else if (btnU_edge) state_next = S_IDLE; 
            S_COOKING:  if (time_reg == 0) state_next = S_FINISHED;
                        else if(i_door_switch) state_next = S_PAUSED;
                        else if (btnD_edge) state_next = S_PAUSED;
                        else if (btnU_edge) state_next = S_IDLE;
            S_PAUSED:   if (btnD_edge && !i_door_switch) state_next = S_COOKING;
                        else if (btnU_edge) state_next = S_IDLE;
            S_FINISHED: if (finish_10s_counter == 10) state_next = S_IDLE;
        endcase
    end

    // FSM 상태별 값 업데이트 로직
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            time_reg <= 0;
            finish_10s_counter <= 0;
            display_toggle_counter <= 0;
        end else begin
            if (state_reg == S_COOKING) begin
                if (sec_tick) display_toggle_counter <= (display_toggle_counter == 9) ? 0 : display_toggle_counter + 1;
            end else begin
                display_toggle_counter <= 0;
            end

            case (state_reg)
                S_IDLE: begin
                    time_reg <= 0;
                    finish_10s_counter <= 0;
                end
                S_TIME_SET: begin
                    if (btnL_edge) time_reg <= time_reg + 5;
                    if (btnC_edge) time_reg <= time_reg + 10;
                    if (btnR_edge) time_reg <= time_reg + 15;
                end
                S_COOKING: begin
                    if (sec_tick && time_reg > 0) begin
                        time_reg <= time_reg - 1;
                    end
                end
                S_PAUSED: begin
                    // 시간 정지
                end
                S_FINISHED: begin
                    if (sec_tick && finish_10s_counter < 10) begin
                        finish_10s_counter <= finish_10s_counter + 1;
                    end
                end
            endcase
        end
    end

    // FSM 출력 로직
    always @(*) begin
        o_finished_blink = (state_reg == S_FINISHED && blink_on);
        o_fnd_blink      = (state_reg == S_FINISHED && !blink_on); 
        o_time_display   = (state_reg == S_FINISHED) ? 0 : time_reg;
        o_show_animation = (state_reg == S_COOKING) && (display_toggle_counter >= 5);
        o_motor_on       = (state_reg == S_COOKING);
        o_servo_active   = (state_reg != S_FINISHED);

        // 핵심 수정: 조리가 끝나는 순간(S_COOKING -> S_FINISHED)에 1클럭 펄스 발생
        if (state_reg == S_COOKING && state_next == S_FINISHED) begin
            o_melody_start = 1'b1;
        end else begin
            o_melody_start = 1'b0;
        end
    end

endmodule
