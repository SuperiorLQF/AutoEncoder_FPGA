`timescale 100ps/1ps
module tb_demo;
logic  sys_clk_p;
logic  sys_clk_n;
logic  rst_n;
logic  fan;
logic  uart_rx;
logic  uart_tx;

localparam BPS_115200 = 86805;
logic [15:0] INPUT_DATA [95:0];
logic [7:0] addr;
localparam  INPUT_PATH ={"/home/superior/AutoEncoder_FPGA/output/mem_file/input_sim.txt"};
bit [7:0] SEND_DATA;
sys_top dut(.*);

initial begin
    sys_clk_p = 1'b0;
    rst_n = 1'b0;

    #50000 rst_n = 1'b1;
end
integer i;
integer j;
initial begin
    $readmemb(INPUT_PATH,INPUT_DATA);
    uart_rx = 1'b1;
    wait(rst_n);
    for(j=0;j<96;j=j+1)begin
        addr = j;
        SEND_DATA = INPUT_DATA[addr][15:8];
        #10000
        uart_send(SEND_DATA);
        SEND_DATA = INPUT_DATA[addr][7:0];
        #10000
        uart_send(SEND_DATA);
    end

end
task automatic uart_send(bit [7:0] data);
    uart_rx = 1'b0;
    for(i=0;i<8;i=i+1)begin
        #BPS_115200 uart_rx = data[i];
    end
    #BPS_115200 uart_rx = 1'b0;
    #BPS_115200 uart_rx = 1'b1;
endtask 
always #25 sys_clk_p = ~sys_clk_p;
assign sys_clk_n = ~sys_clk_p;
endmodule
