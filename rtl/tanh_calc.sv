module tanh_calc
// #(
//     parameter  IN_DAT_W  = 8,
//     parameter  OUT_DAT_W = 8,
//     parameter  BASE_DIR  = "/home/superior/AutoEncoder_FPGA",
//     parameter  MEM_DIR   = "",
//     parameter  MEM_FILE  = "/design/mem_file/tanh_mem.txt"
// )
(
    input                       rst_n   ,
    input                       clk     ,
    input       [7:0]           in_x    ,
    input                       in_valid,
    output  reg [7:0]           out_y   ,
    output  reg                 out_valid  
);
//input [2,6]   -2.00 ～ 1.99 
//如果是正值，则转换为负值，并用最高位取反作为flag
//input_sign [2,6]   -2.00 ~ 0 (负数部分)
//sign_s1 [2,6] -1.00 ~ 0 (负数部分)
//s1_add1 [2,6] 0~1
//add1_pow_origin [4,12] 0~1
//add1_pow [2,7] 0~1
//pow_m1 [2,7] -1~0 
//falg为正则再次取反
wire flag;
wire cond1;
wire [7:0] input_sign;
wire [7:0] sign_s1;
wire [7:0] s1_comp;
wire [9:0] comp_add1_o;
wire [8:0] comp_add1;
wire [17:0] add1_pow_origin;
wire [8:0] add1_pow;
wire [8:0] pow_comp;
wire [8:0] comp_add1_2;
wire [7:0] result;
wire [7:0] result_comp;

assign flag  = in_x[7]; 
assign cond1 = (in_x == 8'b10_000000);
/////////////////////////////////////////////////////////////
assign input_sign = cond1?8'b01_111111:flag?(~in_x+1'b1):in_x; //[2,6] 负半周转换为正的0-1.99
assign sign_s1    = input_sign;//[1,7] 右移 0~0.99
assign s1_comp    = ~sign_s1+1'b1;//[1,7] 补码 -0.99-0
assign comp_add1_o =  {s1_comp[7],s1_comp} + 9'b01_0000000;// [2,7] 0-1
assign comp_add1 = comp_add1_o[8:0];
assign add1_pow_origin = $signed(comp_add1) * $signed(comp_add1);// [4,14] 0-1
assign add1_pow = add1_pow_origin[15:7];//[2,7] 0-1
assign pow_comp = ~add1_pow+1'b1; //[2,7] -1 ~0
assign comp_add1_2 = pow_comp + 9'b01_0000000; //[2,7] 0~1
assign result = (comp_add1_2[8:7] == 2'b01)?8'b0_1111111:comp_add1_2[7:0];//[1,7] 0-0.99
assign result_comp = ~result+1'b1;//[1,7] -0.99-0
///////////////////////////////////////////////////////////////

always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        out_valid <= 1'b0;
        out_y     <= 'd0;
    end
    else if(in_valid)begin
        if(flag)begin//-
            out_y <= result_comp;
            out_valid <= 1'b1;
        end
        else begin//+
            out_y <= result;
            out_valid <= 1'b1;
        end
    end
    else begin
        out_valid <= 1'b0;
    end
end


// localparam  MEM_PATH = {BASE_DIR,MEM_DIR,MEM_FILE};
// reg [OUT_DAT_W-1:0] mem [2**IN_DAT_W-1:0];

// initial begin
//     $readmemb(MEM_PATH,mem);
//     out_y = 'd0;
//     out_valid = 1'b0;
// end

// always @(posedge clk) begin
//     if(in_valid)begin
//         out_y <= mem[in_x];
//         out_valid <= 1'b1;
//     end
//     else begin
//         out_valid <= 1'b0;
//     end
// end
endmodule