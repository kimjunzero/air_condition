`timescale 1ns / 1ps

module aircondition_fsm (
    input clk,
    input reset,
    input w_btnU, w_btnL, w_btnC, w_btnR, w_btnD,
    input danger_close,
    input [1:0] motor_direction,
    input [7:0] current_temp,
    input sw0,
    output reg [2:0] o_display_mode,
    output reg [7:0] o_manual_value,
    output reg [1:0] o_dc_motor_direction,
    output reg [7:0] o_dc_motor_temp_in,
    output reg o_servo_active
);

    // --- FSM 상태 및 디스플레이 모드 정의 ---
    localparam ST_STANDBY = 3'd0, ST_AUTO = 3'd1, ST_SET_TEMP = 3'd2, ST_SET_FAN = 3'd3, ST_SET_TIMER = 3'd4;
    localparam DISP_AUTO = 3'd0, DISP_DIST = 3'd1, DISP_MANUAL = 3'd2, DISP_TARGET = 3'd3, DISP_FAN_LEVEL = 3'd4, DISP_TIMER = 3'd5, DISP_OFF = 3'd6;
    parameter CLK_FREQ = 100_000_000;

    // --- 내부 레지스터 ---
    reg [2:0] current_state, next_state;
    reg [7:0] target_temp_reg;
    reg [1:0] fan_speed_reg;
    reg [7:0] timer_set_seconds_reg;
    reg [15:0] timer_countdown_seconds;
    reg [26:0] one_sec_counter;

    // 버튼 입력 감지
    reg prev_btnC, prev_btnD, prev_btnR, prev_btnL;
    wire btnC_posedge, btnD_posedge, btnR_posedge, btnL_posedge;
    
    // 타이밍 최적화를 위해 조건을 미리 계산하는 wire
    wire timer_is_finished;

    // --- 로직 ---

    // 1. 버튼 Rising Edge 감지
    always @(posedge clk) {prev_btnC, prev_btnD, prev_btnR, prev_btnL} <= {w_btnC, w_btnD, w_btnR, w_btnL};
    assign btnC_posedge = w_btnC & ~prev_btnC;
    assign btnD_posedge = w_btnD & ~prev_btnD;
    assign btnR_posedge = w_btnR & ~prev_btnR;
    assign btnL_posedge = w_btnL & ~prev_btnL;

    assign timer_is_finished = (sw0 && timer_countdown_seconds == 0 && current_state != ST_STANDBY);

    // 2. FSM 다음 상태 결정 로직 (조합 논리)
    always @(*) begin
        next_state = current_state;
        case (current_state)
            ST_STANDBY: if (btnD_posedge) next_state = ST_AUTO;
            ST_AUTO:    if (btnD_posedge) next_state = ST_STANDBY; else if (btnC_posedge) next_state = ST_SET_TEMP;
            ST_SET_TEMP:if (btnD_posedge) next_state = ST_STANDBY; else if (btnC_posedge) next_state = ST_SET_FAN;
            ST_SET_FAN: if (btnD_posedge) next_state = ST_STANDBY; else if (btnC_posedge) next_state = ST_SET_TIMER;
            ST_SET_TIMER:if (btnD_posedge) next_state = ST_STANDBY; else if (btnC_posedge) next_state = ST_AUTO;
        endcase
    end

    // 3. FSM 출력 계산 로직 (조합 논리)
    always @(*) begin
        // 기본값 설정
        o_display_mode = DISP_AUTO;
        o_manual_value = 0;
        o_dc_motor_direction = motor_direction;
        o_dc_motor_temp_in = current_temp;
        o_servo_active = 1'b1;

        case (current_state)
            ST_STANDBY:   {o_display_mode, o_dc_motor_direction, o_servo_active} = {DISP_OFF, 2'b00, 1'b0};
            ST_AUTO:      {o_display_mode, o_dc_motor_temp_in, o_servo_active} = {DISP_AUTO, current_temp, 1'b1};
            ST_SET_TEMP:  {o_display_mode, o_manual_value, o_dc_motor_temp_in, o_servo_active} = {DISP_TARGET, target_temp_reg, target_temp_reg, 1'b1};
            ST_SET_FAN:   begin
                            o_display_mode = DISP_FAN_LEVEL;
                            o_manual_value = fan_speed_reg;
                            case(fan_speed_reg)
                                0: o_dc_motor_temp_in = 0;   1: o_dc_motor_temp_in = 25;
                                2: o_dc_motor_temp_in = 28;  3: o_dc_motor_temp_in = 31;
                                default: o_dc_motor_temp_in = 0;
                            endcase
                            o_servo_active = 1'b1;
                          end
            ST_SET_TIMER: {o_display_mode, o_manual_value, o_dc_motor_temp_in, o_servo_active} = {DISP_TIMER, timer_set_seconds_reg, current_temp, 1'b1};
        endcase
        
        if (sw0 && timer_countdown_seconds > 0 && current_state != ST_STANDBY && current_state != ST_SET_TIMER) begin
            o_display_mode = DISP_TIMER;
            o_manual_value = timer_countdown_seconds;
        end

        if (danger_close) o_dc_motor_direction = 2'b00;
    end

    // 4. FSM 상태 및 값 업데이트 로직 (순차 논리)
    always @(posedge clk or posedge reset) begin
        if (reset || w_btnU) begin
            current_state <= ST_STANDBY;
            target_temp_reg <= 25;
            fan_speed_reg <= 1;
            timer_set_seconds_reg <= 0;
            timer_countdown_seconds <= 0;
            one_sec_counter <= 0;
        end else begin
            if (timer_is_finished) current_state <= ST_STANDBY;
            else current_state <= next_state;

            if (current_state == ST_SET_TEMP) begin
                if (btnR_posedge && target_temp_reg < 30) target_temp_reg <= target_temp_reg + 1;
                if (btnL_posedge && target_temp_reg > 18) target_temp_reg <= target_temp_reg - 1;
            end
            if (current_state == ST_SET_FAN) begin
                if (btnR_posedge && fan_speed_reg < 3) fan_speed_reg <= fan_speed_reg + 1;
                if (btnL_posedge && fan_speed_reg > 0) fan_speed_reg <= fan_speed_reg - 1;
            end
            if (current_state == ST_SET_TIMER) begin
                if (btnR_posedge && timer_set_seconds_reg < 90) timer_set_seconds_reg <= timer_set_seconds_reg + 10;
                if (btnL_posedge && timer_set_seconds_reg > 0) timer_set_seconds_reg <= timer_set_seconds_reg - 10;
            end
            
            if (current_state == ST_SET_TIMER && btnC_posedge) timer_countdown_seconds <= timer_set_seconds_reg;
            
            if (sw0 && timer_countdown_seconds > 0) begin
                if (one_sec_counter >= CLK_FREQ - 1) begin
                    one_sec_counter <= 0;
                    timer_countdown_seconds <= timer_countdown_seconds - 1;
                end else one_sec_counter <= one_sec_counter + 1;
            end else one_sec_counter <= 0;
        end
    end

endmodule
