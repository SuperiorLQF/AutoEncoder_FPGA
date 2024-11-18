`timescale 1ns/100ps

module tb_float2fxp_s;
logic  [31:0]  fp32_i;
logic  [15:0]  fxp_o;
logic          overflow;  

logic [31:0] fp_test [255:0];//256 test number
logic [15:0] fp_result [255:0];
float2fxp_s dut(.*);
integer i;
initial begin
    fp32_i = 'd0;
    $readmemh("/home/superior/AutoEncoder_FPGA/output/tmp/float2fxp_test.hex",fp_test);
    #500;
    for(i=0;i<256;i++)begin
        fp32_i = fp_test [i];
        if(overflow==1)begin
            $display("OVERFLOW ERROR!");
        end
        #20;
        fp_result[i] = fxp_o;
        #20;
    end
    $writememh("/home/superior/AutoEncoder_FPGA/output/tmp/float2fxp_verify.hex",fp_result);
    #500;
end
    
endmodule
