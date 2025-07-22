`timescale 1ns / 1ps

// DHT11 센서 제어 및 데이터 관리 모듈
module dht11_controller(
    input clk,
    input reset,
    input [2:0] btn_debounced,    // 디바운싱된 버튼
    input [7:0] uart_rx_data,     // UART 수신 데이터
    input uart_rx_done,           // UART 수신 완료
    
    // DHT11 센서 인터페이스
    inout dht_data,
    
    // 출력 데이터
    output reg [7:0] temperature, // 온도 (정수부만)
    output reg [7:0] humidity,    // 습도 (정수부만)
    output reg [1:0] display_mode, // 0: 온도, 1: 습도, 2: 자동
    output reg data_ready,        // 새 데이터 준비됨
    output reg [15:0] status_led  // 상태 LED
);

    // DHT11 센서 신호
    wire [7:0] dht_humidity_int, dht_humidity_dec;
    wire [7:0] dht_temp_int, dht_temp_dec;
    wire dht_data_valid, dht_error, dht_busy;
    wire [3:0] dht_error_code;  // 에러 코드 추가
    reg dht_start;
    
    // 타이밍 제어
    reg [25:0] auto_measure_counter;   // 3초 자동 측정
    reg [25:0] auto_display_counter;   // 2초 디스플레이 전환
    reg [1:0] prev_btn;
    
    // 디버깅용 신호
    reg [3:0] last_error_code;  // 마지막 에러 코드 저장
    
    // DHT11 센서 모듈
    dht11_sensor u_dht11_sensor(
        .clk(clk),
        .rst(reset),
        .start(dht_start),
        .dht_data(dht_data),
        .humidity_int(dht_humidity_int),
        .humidity_dec(dht_humidity_dec),
        .temp_int(dht_temp_int),
        .temp_dec(dht_temp_dec),
        .data_valid(dht_data_valid),
        .error(dht_error),
        .busy(dht_busy),
        .error_code(dht_error_code)  // 에러 코드 연결
    );
    
    // 메인 제어 로직
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            temperature <= 25;      // 초기값 (더미 데이터)
            humidity <= 60;         // 초기값 (더미 데이터)
            display_mode <= 2;      // 자동 모드
            data_ready <= 0;
            dht_start <= 0;
            auto_measure_counter <= 0;
            auto_display_counter <= 0;
            prev_btn <= 0;
            last_error_code <= 0;
        end else begin
            prev_btn <= btn_debounced[1:0];
            data_ready <= 0;  // 기본값
            dht_start <= 0;   // 기본값
            
            // 버튼 처리
            if (btn_debounced[0] && !prev_btn[0]) begin
                // 버튼 0: 모드 변경
                display_mode <= (display_mode == 2) ? 0 : display_mode + 1;
                auto_display_counter <= 0;
            end
            
            if (btn_debounced[1] && !prev_btn[1]) begin
                // 버튼 1: 즉시 측정
                dht_start <= 1;
                auto_measure_counter <= 0;
            end
            
            // UART 명령 처리
            if (uart_rx_done) begin
                case (uart_rx_data)
                    8'h54, 8'h74: begin  // 'T', 't' - 온도
                        display_mode <= 0;
                        auto_display_counter <= 0;
                    end
                    8'h48, 8'h68: begin  // 'H', 'h' - 습도
                        display_mode <= 1;
                        auto_display_counter <= 0;
                    end
                    8'h41, 8'h61: begin  // 'A', 'a' - 자동
                        display_mode <= 2;
                        auto_display_counter <= 0;
                    end
                    8'h4D, 8'h6D: begin  // 'M', 'm' - 측정
                        dht_start <= 1;
                        auto_measure_counter <= 0;
                    end
                endcase
            end
            
            // 자동 측정 (5초마다로 변경 - DHT11 안정성 향상)
            if (auto_measure_counter >= 26'd499_999_999) begin
                dht_start <= 1;
                auto_measure_counter <= 0;
            end else begin
                auto_measure_counter <= auto_measure_counter + 1;
            end
            
            // 자동 디스플레이 전환 (2초마다)
            if (display_mode == 2) begin
                if (auto_display_counter >= 26'd199_999_999) begin
                    auto_display_counter <= 0;
                end else begin
                    auto_display_counter <= auto_display_counter + 1;
                end
            end else begin
                auto_display_counter <= 0;
            end
            
            // DHT11 데이터 업데이트
            if (dht_data_valid) begin
                temperature <= dht_temp_int;
                humidity <= dht_humidity_int;
                data_ready <= 1;
            end
            
            // 에러 코드 저장
            if (dht_error) begin
                last_error_code <= dht_error_code;
            end
        end
    end
    
    // 상태 LED 제어
    always @(*) begin
        status_led = 16'h0000;
        
        // 모드 표시 (LED[15:14])
        status_led[15:14] = display_mode;
        
        // 자동 모드에서 현재 표시 중인 데이터 (LED[13])
        if (display_mode == 2) begin
            status_led[13] = (auto_display_counter < 26'd99_999_999) ? 0 : 1;  // 0: 온도, 1: 습도
        end
        
        // DHT11 상태 (LED[12:10])
        status_led[12] = dht_data_valid;
        status_led[11] = dht_error;
        status_led[10] = dht_busy;
        
        // 에러 코드 표시 (LED[9:6]) - 디버깅용
        if (dht_error) begin
            status_led[9:6] = dht_error_code;
        end else begin
            status_led[9:6] = last_error_code;  // 마지막 에러 코드 유지
        end
        
        // 온도 표시 (LED[5:3])
        if (temperature < 20) status_led[5:3] = 3'b001;
        else if (temperature < 25) status_led[5:3] = 3'b011;
        else if (temperature < 30) status_led[5:3] = 3'b111;
        else status_led[5:3] = 3'b111;
        
        // 습도 표시 (LED[2:0])
        if (humidity < 30) status_led[2:0] = 3'b001;
        else if (humidity < 40) status_led[2:0] = 3'b011;
        else if (humidity < 60) status_led[2:0] = 3'b111;
        else status_led[2:0] = 3'b111;
    end

endmodule