//--------------------------------------------------------------------------------------------------------
// Module  : float2fxp
// Type    : synthesizable
// Standard: Verilog 2001 (IEEE1364-2001)
// Function: convert float-point (IEEE754 single precision) to fixed-point
//           combinational logic
//           not recommended due to the long critical path
//--------------------------------------------------------------------------------------------------------

module float2fxp #(
    parameter WOI  = 8,
    parameter WOF  = 8,
    parameter ROUND= 1
)(
    input  wire        [31:0] in,
    output reg  [WOI+WOF-1:0] out,
    output reg                overflow
);

initial {out, overflow} = 0;

localparam [WOI+WOF-1:0] ONEO = 1;

integer ii;

reg        round, sign;
reg [ 7:0] exp2;
reg [23:0] val;
reg signed [31:0] expi;

always @ (*) begin
    round = 0;
    overflow = 0;
    {sign, exp2, val[22:0]} = in;
    val[23] = 1'b1;
    out = 0;
    expi = exp2-127+WOF;
    if( &exp2 )//E=255:inf or NaN
        overflow = 1'b1;
    else if( in[30:0]!=0 ) begin//not 0
        for(ii=23; ii>=0; ii=ii-1) begin
            if(val[ii]) begin
                if(expi>=WOI+WOF-1)
                    overflow = 1'b1;
                else if(expi>=0)
                    out[expi] = 1'b1;
                else if(ROUND && expi==-1)
                    round=1'b1;
            end
            expi = expi - 1;
        end
        if(round) out=out+1;
    end
    if(overflow) begin
        if(sign) begin
            out[WOI+WOF-1]   = 1'b1;
            out[WOI+WOF-2:0] = 0;
        end else begin
            out[WOI+WOF-1]   = 1'b0;
            out[WOI+WOF-2:0] = {(WOI+WOF){1'b1}};
        end
    end else begin
        if(sign)
            out = (~out) + ONEO;
    end
end

endmodule