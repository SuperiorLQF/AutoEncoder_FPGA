module weight_memory#(
    parameter   WEIGHT_NUM  = 96    ,
    parameter   WEIGHT_W    = 8     ,
    parameter   BASE_DIR    = "/home/superior/BCI_compression"  ,
    parameter   MEM_DIR     = "",
    parameter   WEIGHT_FILE = ""
)(
    input                                   clk     ,
    input       [$clog2(WEIGHT_NUM)-1:0]    addr    ,
    input                                   ren     ,
    output  reg [WEIGHT_W-1:0]              weight  ,
    output  reg                             weight_valid 
);
localparam  MEM_PATH = {BASE_DIR,MEM_DIR,WEIGHT_FILE};
reg [WEIGHT_W-1:0] mem [WEIGHT_NUM-1:0];

initial begin
    $readmemb(MEM_PATH,mem);
    weight = 'd0;
    weight_valid = 1'b0;
end

always@(posedge clk)begin
    if(ren)begin
        weight <= mem[addr];
        weight_valid <= 1'b1;
    end
    else begin
        weight <= 'd0;
        weight_valid <= 1'b0;
    end
end

endmodule