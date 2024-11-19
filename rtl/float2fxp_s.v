module float2fxp_s #(
    parameter WOI = 9,
    parameter WOF = 7
)(  
    input   [31:0]  fp32_i,
    output  [15:0]  fxp_o,
    output          overflow       
);
wire signed [7:0]  exp_real;
wire s;
wire [7:0]     e;
wire [22:0]    m;
wire zero_flag;
wire [15:0] fxp_bfs;//before shift
wire [15:0] fxp_s;
assign s = fp32_i[31];
assign e = fp32_i[30:23];
assign m = fp32_i[22:0];
assign exp_real = e - 127;
//////////////////////////////
//超量程判断
//////////////////////////////
assign overflow = (exp_real >= WOI-1);
assign zero_flag= (exp_real < -WOF);

//////////////////////////////
//截断与拼接
//////////////////////////////
assign fxp_bfs = overflow ? s?16'b1000_0000_0000_0000:16'b0111_1111_1111_1111:
                 zero_flag? 16'd0:
                 {2'b01,m[22-:(WOI+WOF-2)]};
assign fxp_s = fxp_bfs >>(WOI-2-exp_real);
assign fxp_o = s?(~fxp_s)+1'b1:
                 fxp_s;

endmodule