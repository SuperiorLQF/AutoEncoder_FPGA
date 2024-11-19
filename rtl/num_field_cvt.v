module num_field_cvt#(
    parameter WOI_IN    = 9,
    parameter WOI_OUT   = 1,
    parameter WOF_IN    = 7,
    parameter WOF_OUT   = 7,
    parameter ADDR_MW   = 15,
    parameter ADDR_SW   = 12

)(
    input   [ADDR_MW-1:0]   bc_addr_m       ,
    input   [63:0]          bc_din_fp32x2   ,
    output  [63:0]          bc_dout_fp32x2  ,
    output  [ADDR_SW-1:0]   bc_addr_s       ,
    output  [31:0]          bc_din_fxpx2    ,
    input   [31:0]          bc_dout_fxpx2   ,
    input   [7:0]           bc_we_m         ,
    output                  bc_we_s         
);
assign bc_we_s = bc_we_m[0];
assign bc_addr_s = bc_addr_m[ADDR_MW-1:3];
float2fxp_s #(
    .WOI(WOI_IN),
    .WOF(WOF_IN)
)float2fxp_h(  
    .fp32_i     (bc_din_fp32x2[63:32]),
    .fxp_o      (bc_din_fxpx2[31:16]),
    .overflow   ()       
);
float2fxp_s #(
    .WOI(WOI_IN),
    .WOF(WOF_IN)
)float2fxp_l(  
    .fp32_i     (bc_din_fp32x2[31:0]),
    .fxp_o      (bc_din_fxpx2[15:0]),
    .overflow   ()       
);

fxp2float_s #(
    .WOI(WOI_OUT),
    .WOF(WOF_OUT)
)fxp2float_h(
    .fxp        (bc_dout_fxpx2[23:16]),
    .fp32       (bc_dout_fp32x2[63:32])
);
fxp2float_s #(
    .WOI(WOI_OUT),
    .WOF(WOF_OUT)
)fxp2float_l(
    .fxp        (bc_dout_fxpx2[7:0]),
    .fp32       (bc_dout_fp32x2[31:0])
);
endmodule