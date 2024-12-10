//*********************
//version 1.0.0
//*********************

module vv_mac_pe#(
    parameter   INPUT_W     = 16,
    parameter   WEIGHT_W    = 8,
    parameter   BIAS_W      = 15,
    parameter   OUTPUT_W    = 17,
    parameter   OVERLFOW_W  = 9//12-3  CALC_W - OUTPT_W
)(
    input                   clk     ,
    input                   rst_n   ,
    input   [INPUT_W-1:0]   din     ,   //Q9.7    
    input   [BIAS_W-1:0]    bias    ,   //Q1.14
    input   [WEIGHT_W-1:0]  weight  ,   //Q1.7
    input                   sel     ,
    input                   en      ,   //en=0 hold
    input                   clr     ,   //clr=1 clear
    output  [OUTPUT_W-1:0]  dout  //Q3.14
);

localparam  CALC_W = WEIGHT_W + INPUT_W + 2;//12.14
wire [CALC_W-1:0]       result_mul;
wire [CALC_W-1:0]       result_add;
wire [CALC_W-1:0]       result_sel;
wire [INPUT_W-1:0]      din_s;
reg  [CALC_W-1:0]       dout_tmp;
//--------MUL----------------------------------
assign din_s = en?din:0;
assign result_mul = $signed(weight) * $signed(din_s);

//--------SEL----------------------------------
assign result_sel = sel?{{(CALC_W-BIAS_W){bias[BIAS_W-1]}},bias}:result_mul;

//--------ADD----------------------------------
assign result_add = $signed(dout_tmp) + $signed(result_sel);

//-------OUT-----------------------------------
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        dout_tmp <= 'd0;
    end
    else if(clr)begin
        dout_tmp <= 'd0;
    end
    else if(en)begin
        dout_tmp <= result_add;
    end
end
assign dout = ($signed(dout_tmp) >= $signed({{(OVERLFOW_W+1){1'b0}},{(OUTPUT_W-1){1'b1}}}))?{1'b0,{(OUTPUT_W-1){1'b1}}}://overflow
              ($signed(dout_tmp) <= $signed({{(OVERLFOW_W+1){1'b1}},1'b1,{(OUTPUT_W-2){1'b0}}}))?{1'b1,{(OUTPUT_W-1){1'b0}}}:dout_tmp[CALC_W-1-OVERLFOW_W-:OUTPUT_W];//underflow        
                                                        
endmodule