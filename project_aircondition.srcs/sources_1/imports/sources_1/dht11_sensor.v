`timescale 1ns / 1ps

module dht11_sensor (
    input clk,
    input rst_n, // Active-low reset
    inout dht11_data,  // 센서 데이터 핀
    output reg [7:0] humidity, // 습도 데이터
    output reg [7:0] temperature, // 온도 데이터
    output      wire DHT11_done  // 1-clock pulse, 데이터 수신 완료 신호
);

    // FSM 상태 정의
    parameter S_IDLE       = 6'b00_0001;
    parameter S_LOW_18MS   = 6'b00_0010;
    parameter S_HIGH_20US  = 6'b00_0100;
    parameter S_LOW_80US   = 6'b00_1000;
    parameter S_HIGH_80US  = 6'b01_0000;
    parameter S_READ_DATA  = 6'b10_0000;

    parameter S_WAIT_PEDGE = 2'b01;
    parameter S_WAIT_NEDGE = 2'b10;

    reg [21:0] count_usec;
    wire clk_usec;
    reg count_usec_e;

    // 클럭 분주기 모듈 연결 (active-high reset으로 변환)
    wire rst_p = ~rst_n;
    clock_div_100 us_clk (.clk(clk), .reset_p(rst_p), .clk_div_100(clk_usec));

    // 1마이크로초 카운터
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            count_usec <= 0;
        else if (clk_usec && count_usec_e) 
            count_usec <= count_usec + 1;
        else if (!count_usec_e) 
            count_usec <= 0;
    end

    // --- 비동기 입력 동기화 (2-Flop Synchronizer) ---
    reg [1:0] dht_data_sync_ff;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            dht_data_sync_ff <= 2'b11; // Idle-high
        else        
            dht_data_sync_ff <= {dht_data_sync_ff[0], dht11_data};
    end

    wire dht_data_s = dht_data_sync_ff[1]; // 동기화된 신호

    // --- 동기화된 신호를 이용한 엣지 감지 ---
    reg dht_data_s_dly;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) dht_data_s_dly <= 1'b1;
        else dht_data_s_dly <= dht_data_s;
    end
    
    wire dht_pedge =  dht_data_s & ~dht_data_s_dly;
    wire dht_nedge = ~dht_data_s &  dht_data_s_dly;

    reg [5:0] state, next_state;
    reg [1:0] read_state;
    reg [39:0] temp_data;
    reg [5:0] data_count;
    reg dht11_out_en_reg;
    reg done_reg;

    assign dht11_data = dht11_out_en_reg ? 1'b0 : 1'bz; // 1이면 Low 출력, 0이면 High-Z (입력)

    // done 신호 1클럭 펄스 생성
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) done_reg <= 0;
        else if (done_reg) done_reg <= 0; // 1클럭 후 리셋
        else if (state == S_READ_DATA && data_count == 40) done_reg <= 1;
    end
    assign DHT11_done = done_reg;

    // --- 내부 트리거 펄스 생성 로직 ---
    reg [23:0] auto_trigger_cnt; // 1us 단위로 5초 (5,000,000us)까지 카운트 가능
    reg auto_trigger_pulse;      // 내부에서 생성될 트리거 펄스

    parameter TRIGGER_PERIOD_US = 5_000_000; // 5초 (5,000,000 us)마다 트리거

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            auto_trigger_cnt <= 0;
            auto_trigger_pulse <= 0;
        end else begin
            auto_trigger_pulse <= 0; // 기본적으로 펄스를 0으로 유지

            // 1us 클럭으로 주기 카운트
            if (clk_usec) begin // 1us마다
                if (state == S_IDLE) begin // IDLE 상태일 때만 카운트
                    if (auto_trigger_cnt == TRIGGER_PERIOD_US - 1) begin
                        auto_trigger_cnt <= 0;
                        auto_trigger_pulse <= 1; // 1클럭 펄스 생성
                    end else begin
                        auto_trigger_cnt <= auto_trigger_cnt + 1;
                    end
                end else begin // IDLE 상태가 아니면 카운터 멈춤 (측정 중)
                    auto_trigger_cnt <= 0; // 카운터를 리셋하여 다음 트리거를 처음부터 기다리게 함
                end
            end
        end
    end

    // FSM 구현
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_usec_e <= 0;
            next_state <= S_IDLE;
            read_state <= S_WAIT_PEDGE;
            data_count <= 0;
            dht11_out_en_reg <= 0;
            state <= S_IDLE;
            humidity <= 0;
            temperature <= 0;
        end else begin
            state <= next_state; // 상태 전이

            case (state)
                S_IDLE: begin
                    count_usec_e <= 0;
                    dht11_out_en_reg <= 0; // Release line
                    // trigger 대신 내부에서 생성된 auto_trigger_pulse 사용
                    if (auto_trigger_pulse) begin // auto_trigger_pulse가 1일 때
                        next_state <= S_LOW_18MS;
                    end
                end

                S_LOW_18MS: begin
                    if (count_usec < 18000) begin
                        dht11_out_en_reg <= 1; // Drive line low
                        count_usec_e <= 1;
                    end else begin
                        next_state <= S_HIGH_20US;
                        count_usec_e <= 0;
                        dht11_out_en_reg <= 0; // Release line
                    end
                end

                S_HIGH_20US: begin
                    count_usec_e <= 1;
                    if (count_usec > 100) begin // 100us timeout
                        next_state <= S_IDLE; // 응답 없음 시 재시도
                        count_usec_e <= 0;
                    end
                    if (dht_nedge) begin
                        next_state <= S_LOW_80US;
                        count_usec_e <= 0;
                    end
                end

                S_LOW_80US: begin
                    count_usec_e <= 1;
                    if (count_usec > 100) begin // 100us timeout
                        next_state <= S_IDLE;
                        count_usec_e <= 0;
                    end
                    if (dht_pedge) begin
                        next_state <= S_HIGH_80US;
                        count_usec_e <= 0;
                    end
                end

                S_HIGH_80US: begin
                    if (dht_nedge) next_state <= S_READ_DATA;
                end
                S_READ_DATA: begin
                    case (read_state)
                        S_WAIT_PEDGE: begin
                            if (dht_pedge) read_state <= S_WAIT_NEDGE;
                            count_usec_e <= 0; // High 펄스 시작 시 카운터 리셋
                        end
                        S_WAIT_NEDGE: begin
                            if (dht_nedge) begin
                                if (count_usec < 45)
                                    temp_data <= {temp_data[38:0], 1'b0}; // 0
                                else
                                    temp_data <= {temp_data[38:0], 1'b1}; // 1

                                data_count <= data_count + 1;
                                read_state <= S_WAIT_PEDGE;
                            end else begin
                                count_usec_e <= 1;
                                if (count_usec > 200) begin // 200us timeout for bit read
                                    next_state <= S_IDLE;
                                    count_usec_e <= 0;
                                    data_count <= 0;
                                    read_state <= S_WAIT_PEDGE;
                                end
                            end
                        end
                    endcase
                    if (data_count >= 40) begin
                        data_count <= 0;
                        next_state <= S_IDLE;
                        // 체크섬 검증
                        if ((temp_data[39:32] + temp_data[31:24] + temp_data[23:16] + temp_data[15:8]) == temp_data[7:0]) begin
                            humidity <= temp_data[39:32];
                            temperature <= temp_data[23:16];
                        end
                    end
                end
                default: next_state <= S_IDLE;

            endcase
        end
    end
endmodule

// clock_div_100 모듈은 변경 없음
module clock_div_100 (
    input clk,
    input reset_p,
    output reg clk_div_100
);
    reg [6:0] cnt;

    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            cnt <= 0;
            clk_div_100 <= 0;
        end else if (cnt == 99) begin
            cnt <= 0;
            clk_div_100 <= 1;
        end else begin
            cnt <= cnt + 1;
            clk_div_100 <= 0;
        end
    end
endmodule