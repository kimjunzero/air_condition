// uart_manager.v
`timescale 1ns / 1ps

module uart_manager(
    input clk,
    input reset,
    
    // 모든 데이터 소스 (순수 이진수 값으로 가정, 예: 온도 25 -> 8'd25)
    input [7:0] temperature, // 0~99 (2자리)
    input [7:0] humidity,    // 0~99 (2자리)
    input [7:0] distance,    // 0~99 (2자리)
    
    // UART 포트
    input rx,
    output tx,
    output reg [7:0] rx_data,
    output reg rx_done
);

    // TX FSM 상태 정의
    localparam STATE_IDLE_TX = 0,
               STATE_SEND = 1; // 단일 STATE_SEND 상태 유지

    // 전송 모드 정의
    localparam MODE_NONE = 0,
               MODE_TEMP_HUM = 1, // 온습도 전송 모드
               MODE_DIST = 2;     // 거리 전송 모드

    reg state_tx = STATE_IDLE_TX;
    reg tx_start_pulse = 0; // uart_tx 모듈로 1클럭 펄스 전달
    reg [7:0] data_to_send = 0; // UART TX로 보낼 실제 데이터
    wire tx_busy_wire;          // UART TX가 전송 중인지 여부
    
    reg [1:0] send_mode; // 현재 어떤 데이터를 보낼지 저장하는 레지스터
    reg [5:0] step;      // 전송 단계 카운터 (충분히 크게 둠)

    // --- bin2bcd 모듈 인스턴스화 ---
    // 온도 데이터 변환: 8비트 이진수(0~255)를 10진수 자릿수로 변환
    wire [3:0] temp_d1000, temp_d100, temp_d10, temp_d1;
    bin2bcd u_temp_to_bcd (
        .in_data({6'b0, temperature}), 
        .d1000(temp_d1000),
        .d100(temp_d100),
        .d10(temp_d10),
        .d1(temp_d1)
    );

    // 습도 데이터 변환
    wire [3:0] hum_d1000, hum_d100, hum_d10, hum_d1;
    bin2bcd u_hum_to_bcd (
        .in_data({6'b0, humidity}),
        .d1000(hum_d1000),
        .d100(hum_d100),
        .d10(hum_d10),
        .d1(hum_d1)
    );

    // 거리 데이터 변환
    wire [3:0] dist_d1000, dist_d100, dist_d10, dist_d1;
    bin2bcd u_dist_to_bcd (
        .in_data({6'b0, distance}),
        .d1000(dist_d1000),
        .d100(dist_d100),
        .d10(dist_d10),
        .d1(dist_d1)
    );

    // UART TX 모듈 인스턴스화
    uart_tx u_uart_tx (
        .i_clk(clk),
        .i_tx_start(tx_start_pulse),
        .i_tx_data(data_to_send),
        .o_tx_busy(tx_busy_wire),
        .o_tx_serial(tx)
    );

    // TX FSM (상태 머신)
    always @(posedge clk or posedge reset) begin
        if(reset) begin
            state_tx <= STATE_IDLE_TX;
            tx_start_pulse <= 0;
            step <= 0;
            send_mode <= MODE_NONE;
            data_to_send <= 0;
        end else begin
            tx_start_pulse <= 0; // 매 클럭 사이클마다 기본적으로 0으로 설정

            case(state_tx)
                STATE_IDLE_TX: begin
                    if (rx_done && !tx_busy_wire) begin // 요청 수신 및 TX 유휴
                        case (rx_data)
                            "A": begin // 온습도 요청
                                send_mode <= MODE_TEMP_HUM;
                                step <= 0; // 첫 단계부터 시작
                                state_tx <= STATE_SEND;
                            end
                            "M": begin // 거리 요청
                                send_mode <= MODE_DIST;
                                step <= 0; // 첫 단계부터 시작
                                state_tx <= STATE_SEND;
                            end
                        endcase
                    end
                end

                STATE_SEND: begin
                    // 다음 step으로 넘어가야 할 때 (이전 전송 완료 및 현재 step이 마지막이 아닐 때)
                    if(!tx_busy_wire || (step == 0 && (send_mode == MODE_TEMP_HUM || send_mode == MODE_DIST))) begin
                        // step == 0일 때는 tx_busy_wire를 기다리지 않고 바로 전송 시작
                        // 그 외에는 tx_busy_wire가 Low일 때만 다음 전송 진행
                        
                        case(send_mode)
                            // --- 모드 1: 온습도 전송 ('A' 입력 시) ---
                            MODE_TEMP_HUM: begin
                                case(step)
                                    0: data_to_send <= "T"; 
                                    1: data_to_send <= ":"; 
                                    2: data_to_send <= temp_d10 + "0"; 
                                    3: data_to_send <= temp_d1 + "0";  
                                    4: data_to_send <= " "; 
                                    5: data_to_send <= "H"; 
                                    6: data_to_send <= ":"; 
                                    7: data_to_send <= hum_d10 + "0"; 
                                    8: data_to_send <= hum_d1 + "0";  
                                    9: data_to_send <= 8'h0D; 
                                    10: data_to_send <= 8'h0A; 
                                    default: begin // 모든 단계 완료
                                        tx_start_pulse <= 0;
                                        state_tx <= STATE_IDLE_TX; 
                                        send_mode <= MODE_NONE; 
                                        step <= 0; 
                                    end
                                endcase
                                // 마지막 단계가 아니라면 tx_start_pulse를 인가하고 step 증가
                                if (step <= 10) begin 
                                    tx_start_pulse <= 1; 
                                    step <= step + 1;
                                end
                            end
                            // --- 모드 2: 초음파 거리 전송 ('M' 입력 시) ---
                            MODE_DIST: begin
                                case(step)
                                    0: data_to_send <= "M"; 
                                    1: data_to_send <= ":"; 
                                    2: data_to_send <= " "; 
                                    3: data_to_send <= dist_d10 + "0"; 
                                    4: data_to_send <= dist_d1 + "0";  
                                    5: data_to_send <= "c"; 
                                    6: data_to_send <= "m"; 
                                    7: data_to_send <= 8'h0D; 
                                    8: data_to_send <= 8'h0A; 
                                    default: begin 
                                        tx_start_pulse <= 0;
                                        state_tx <= STATE_IDLE_TX;
                                        send_mode <= MODE_NONE;
                                        step <= 0; 
                                    end
                                endcase
                                if (step <= 8) begin 
                                    tx_start_pulse <= 1;
                                    step <= step + 1;
                                end
                            end
                        endcase
                    end
                end
            endcase
        end
    end

    // --- UART 수신(RX) 로직 ---
    wire rx_data_valid;
    wire [7:0] rx_data_wire;

    uart_rx u_uart_rx (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data_out(rx_data_wire),
        .rxdone(rx_data_valid)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_data <= 8'd0;
            rx_done <= 1'b0;
        end else begin
            rx_done <= 1'b0;
            if (rx_data_valid) begin
                rx_data <= rx_data_wire;
                rx_done <= 1'b1;
            end
        end
    end
endmodule