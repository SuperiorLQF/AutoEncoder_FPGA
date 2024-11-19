module fxp2float_s #(
    parameter WOI = 1,
    parameter WOF = 7
)(
    input   [7:0]  fxp,
    output  [31:0]  fp32
);
    wire all_zero;
    wire s;
    wire [7:0]  e;
    wire [22:0] m;
    wire [7:0] fxp_abs;
    integer i;
    reg [2:0] lead_one_pos;
    assign all_zero = ~(|fxp);
    assign s = fxp[7];
    assign fxp_abs = s?(~fxp)+1'b1:fxp;
    always@(*)begin
        lead_one_pos = 'd0;
        for(i=0;i<7;i=i+1)begin
            if(fxp_abs[i])begin
                lead_one_pos = $unsigned(i);            
            end
        end
    end
    assign m = {fxp_abs << (8-lead_one_pos),{(23-8){1'b0}}};
    assign e = lead_one_pos + 120;
    assign fp32 = all_zero?'d0:{s,e,m};
endmodule