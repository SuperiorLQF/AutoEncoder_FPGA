module tanh_af#(
    parameter VVMAC_IN_W    = 16,  // Q9,7
    parameter VVMAC_OUT_W   = 17,  // Q3,14
    parameter MEM_PATH      = "/home/superior/AutoEncoder_FPGA/output/mem_file/tanh_pos.txt"
)(
    input   [VVMAC_OUT_W-1:0] afi,
    output  [VVMAC_IN_W-1 :0] afo
);
reg  [14:0] tanh_table [255:0]; //Q8,7
initial begin
    $readmemb(MEM_PATH,tanh_table);
end

wire [7:0] addr;
wire sign_flag;
wire [VVMAC_OUT_W-2:0] afi_positive;//Q2,14 unsigned
wire [VVMAC_IN_W-2:0]  tanh_positive;//Q8,7 unsigned
assign sign_flag = afi[VVMAC_OUT_W-1];
assign afi_positive = sign_flag?(afi=={1'b1,{(VVMAC_OUT_W-1){1'b0}}})?  {(VVMAC_OUT_W-1){1'b1}}:        
                                                                        ~afi[VVMAC_OUT_W-2:0]+1'b1:     
                                                                        afi[VVMAC_OUT_W-2:0];
assign addr =  afi_positive[15:8];//256table                                                                       
assign tanh_positive = (afi_positive < 16'b00_0100_0000_0000_00)?   {6'b000_000,afi_positive[VVMAC_OUT_W-2:7]}:
                                                                    tanh_table[addr]; 
assign afo =   sign_flag?{1'b1,{~tanh_positive + 1'b1}}: {1'b0,tanh_positive};                                                                 
endmodule