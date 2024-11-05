module tanh_calc#(
    parameter  IN_DAT_W  = 8,
    parameter  OUT_DAT_W = 8,
    parameter  BASE_DIR  = "/home/superior/AutoEncoder_FPGA",
    parameter  MEM_DIR   = "",
    parameter  MEM_FILE  = "/design/mem_file/tanh_mem.txt"
)(
    input                       clk     ,
    input       [IN_DAT_W-1:0]  in_x    ,
    input                       in_valid,
    output  reg [OUT_DAT_W-1:0] out_y   ,
    output  reg                 out_valid  
);
localparam  MEM_PATH = {BASE_DIR,MEM_DIR,MEM_FILE};
reg [OUT_DAT_W-1:0] mem [2**IN_DAT_W-1:0];

initial begin
    $readmemb(MEM_PATH,mem);
    out_y = 'd0;
    out_valid = 1'b0;
end

always @(posedge clk) begin
    if(in_valid)begin
        out_y <= mem[in_x];
        out_valid <= 1'b1;
    end
    else begin
        out_valid <= 1'b0;
    end
end
endmodule