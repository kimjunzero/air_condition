`timescale 1ns / 1ps

module fnd_animation (
    input clk,
    input reset,
    output reg [7:0] seg,
    output reg [3:0] an
);
    parameter DELAY = 27'd20_000_000;
    parameter S_A = 8'b11111110, S_B = 8'b11111101, S_C = 8'b11111011;
    parameter S_D = 8'b11110111, S_E = 8'b11101111, S_F = 8'b11011111;
    parameter ALL_OFF = 8'hFF;
    
    reg [26:0] anim_counter = 0;
    reg [17:0] mux_counter = 0;
    reg  [3:0] anim_state = 0;
    wire [1:0] mux_select;

    reg [7:0] seg_d3, seg_d2, seg_d1, seg_d0;

    assign mux_select = mux_counter[17:16];
    
    always @(posedge clk or posedge reset) begin
        if(reset) mux_counter <= 0;
        else      mux_counter <= mux_counter + 1;
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            anim_counter <= 0;
            anim_state <= 0;
        end else if (anim_counter >= DELAY - 1) begin
            anim_counter <= 0;
            anim_state <= (anim_state == 11) ? 0 : anim_state + 1;
        end else begin
            anim_counter <= anim_counter + 1;
        end
    end

    always @(*) begin
        seg_d3 = ALL_OFF; seg_d2 = ALL_OFF;
        seg_d1 = ALL_OFF; seg_d0 = ALL_OFF;
        
        case (anim_state)
            0: seg_d3=S_A; 1: seg_d2=S_A;  2: seg_d1=S_A;  3: seg_d0=S_A;
            4: seg_d0=S_B; 5: seg_d0=S_C;  6: seg_d0=S_D;  7: seg_d1=S_D;
            8: seg_d2=S_D; 9: seg_d3=S_D; 10: seg_d3=S_E; 11: seg_d3=S_F;
        endcase
    end

    always @(posedge clk) begin
        case (mux_select)
            2'b00: begin an <= 4'b1110; seg <= seg_d0; end
            2'b01: begin an <= 4'b1101; seg <= seg_d1; end
            2'b10: begin an <= 4'b1011; seg <= seg_d2; end
            2'b11: begin an <= 4'b0111; seg <= seg_d3; end
        endcase
    end
endmodule