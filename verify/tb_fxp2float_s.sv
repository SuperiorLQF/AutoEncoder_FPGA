`timescale 1ns/100ps

module tb_fxp2float_s;
logic  [31:0]  fp32;
logic  [7:0]   fxp;

logic [7:0]  fxp_test   [255:0];//256 test number
logic [31:0] fp_result [255:0];
fxp2float_s dut(.*);
integer i;
initial begin
    fxp = 'd0;
    $readmemh("/home/superior/AutoEncoder_FPGA/output/tmp/fxp2float_test.hex",fxp_test);
    #500;
    for(i=0;i<256;i++)begin
        fxp = fxp_test [i];
        #20;
        fp_result[i] = fp32;
        #20;
    end
    $writememh("/home/superior/AutoEncoder_FPGA/output/tmp/fxp2float_verify.hex",fp_result);
    #500;
end
    
endmodule
