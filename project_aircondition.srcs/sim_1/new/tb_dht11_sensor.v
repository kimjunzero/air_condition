`timescale 1ns / 1ps

module tb_dht11_sensor;

    // --- Testbench Internal Signals ---
    reg clk;
    reg rst_n;
    wire [7:0] humidity;
    wire [7:0] temperature;
    wire DHT11_done;
    wire dht11_data_from_dut;
    reg  dht11_data_to_dut;
    wire dht11_data;

    // ◀◀ 수정: 시뮬레이션 시간을 200us로 대폭 단축
    defparam uut.TRIGGER_PERIOD_US = 200;

    // --- Instantiate the DUT ---
    dht11_sensor uut (
        .clk(clk),
        .rst_n(rst_n),
        .dht11_data(dht11_data),
        .humidity(humidity),
        .temperature(temperature),
        .DHT11_done(DHT11_done)
    );

    // --- Clock Generation (100MHz) ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --- Inout Port Handling (소프트웨어 풀업 방식) ---
    assign dht11_data = (dht11_data_to_dut !== 1'bz) ? dht11_data_to_dut : 1'b1;
    assign dht11_data_from_dut = dht11_data;

    // --- Simulation Sequence ---
    initial begin
        $display("INFO: Simulation Started.");
        
        rst_n = 1'b1;
        dht11_data_to_dut = 1'bz;
        #100;
        
        rst_n = 1'b0;
        $display("INFO: Reset Asserted.");
        #100;
        
        rst_n = 1'b1;
        $display("INFO: Reset Deasserted. Waiting for DUT to start communication...");

        wait (dht11_data_from_dut == 1'b0);
        $display("INFO: DUT pulled the line LOW.");
        
        wait (dht11_data_from_dut == 1'b1);
        $display("INFO: DUT released the line HIGH.");

        // Testbench (sensor) responds
        dht11_data_to_dut = 1'b0; #80_000;
        dht11_data_to_dut = 1'b1; #80_000;

        // Send data: H=53%(0x35), T=26C(0x1A), Checksum=0x4F
        send_data(40'h35001A004F);
        
        dht11_data_to_dut = 1'bz;
        $display("INFO: 40 bits sent. Releasing line.");

        wait (DHT11_done == 1'b1);
        $display("INFO: DHT11_done pulse received.");
        
        #10;

        if (humidity == 8'h35 && temperature == 8'h1A)
            $display("SUCCESS: Correct data received. H=0x%h, T=0x%h", humidity, temperature);
        else
            $error("FAILURE: Incorrect data. Expected H=0x35, T=0x1A. Got H=0x%h, T=0x%h", humidity, temperature);

        #1000;
        $display("INFO: Simulation Finished.");
        $finish;
    end

    // --- Task to send 40 bits of data ---
    task send_data;
        input [39:0] data_to_send;
        integer i;
    begin
        for (i = 39; i >= 0; i = i - 1) begin
            dht11_data_to_dut = 1'b0; #50_000; // Start bit pulse
            dht11_data_to_dut = 1'b1; // Data pulse
            if (data_to_send[i] == 1'b0) #27_000; // ~27us for '0'
            else #70_000; // 70us for '1'
        end
    end
    endtask

endmodule
