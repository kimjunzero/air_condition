`timescale 1ns / 1ps

module uart_tx(
    input           i_clk,      // 시스템 클럭 (100MHz)
    input           i_tx_start, // 1클럭 동안 High 신호를 주면 데이터 전송 시작
    input   [7:0]   i_tx_data,  // 전송할 8비트 데이터
    output          o_tx_busy,  // 전송 중일 때 High
    output          o_tx_serial // 실제 데이터가 1비트씩 출력되는 핀
    );

    // 파라미터 설정
    localparam CLK_FREQ = 100_000_000; // 시스템 클럭 주파수
    localparam BAUD_RATE = 9600;       // 원하는 보드레이트
    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE; // 1비트를 전송하는 데 필요한 클럭 수

    // 상태(FSM) 정의
    localparam FSM_IDLE = 2'b00,
               FSM_DATA = 2'b01,
               FSM_STOP = 2'b10;

    // 내부 레지스터
    reg [1:0]  state = FSM_IDLE;
    reg [15:0] clk_counter = 0;     // 보드레이트 생성을 위한 카운터
    reg [3:0]  bit_index = 0;       // 현재 전송 중인 비트 인덱스 (0~7)
    reg [7:0]  tx_data_reg = 0;     // 전송할 데이터를 저장할 레지스터
    reg        tx_busy_reg = 0;
    reg        tx_pin_reg = 1'b1;   // UART TX 핀은 평소에 High

    assign o_tx_busy = tx_busy_reg;
    assign o_tx_serial = tx_pin_reg;

    always @(posedge i_clk) begin
        case (state)
            // ==================== IDLE 상태 ====================
            FSM_IDLE: begin
                tx_pin_reg <= 1'b1; // TX 핀 High 유지
                tx_busy_reg <= 1'b0;
                bit_index <= 0;
                clk_counter <= 0;

                // 전송 시작 신호가 들어오면
                if (i_tx_start) begin
                    tx_data_reg <= i_tx_data; // 보낼 데이터 저장
                    tx_pin_reg <= 1'b0;      // Start Bit (LOW) 전송 시작
                    tx_busy_reg <= 1'b1;
                    state <= FSM_DATA;
                end
            end

            // ==================== DATA 전송 상태 ====================
            FSM_DATA: begin
                // 1비트 전송 주기가 되면
                if (clk_counter < CLKS_PER_BIT - 1) begin
                    clk_counter <= clk_counter + 1;
                end else begin
                    clk_counter <= 0;
                    
                    // 모든 비트(0~7)를 다 보냈으면 STOP 상태로 이동
                    if (bit_index >= 8) begin
                        tx_pin_reg <= 1'b1; // Stop Bit (HIGH)
                        state <= FSM_STOP;
                    end
                    // 아직 보낼 비트가 남았으면
                    else begin
                        tx_pin_reg <= tx_data_reg[bit_index]; // 데이터의 해당 비트 출력
                        bit_index <= bit_index + 1;
                    end
                end
            end

            // ==================== STOP 비트 전송 상태 ====================
            FSM_STOP: begin
                // 1비트 전송 주기가 되면 IDLE 상태로 복귀
                if (clk_counter < CLKS_PER_BIT - 1) begin
                    clk_counter <= clk_counter + 1;
                end else begin
                    state <= FSM_IDLE;
                end
            end

            default:
                state <= FSM_IDLE;
        endcase
    end

endmodule