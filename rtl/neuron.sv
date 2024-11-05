//优化方向：
//主数据路径无复位寄存器
//clk gating
//防止不需要的翻转向后传递

//-------<DEF FIX>------------//
//in_dat:       [9,7]
//weight:       [1,7]
//mul:          [10,14]
//mul_d:        [10,14]
//bias:         [1,14]
//num_sel:      [10,14]
//add_result:   [10,14]
//sum:          [10,14]
//sum_short:    [10,6]
//act_in:       [2,6]
//out_dat       [1,7]
///////////////////////////////

module neuron#(
    parameter   WEIGHT_NUM  = 96,
    parameter   INPUT_W     = 16,
    parameter   WEIGHT_W    = 8,
    parameter   BIAS_W      = 15,
    parameter   OUTPUT_W    = 8,
    parameter   ACT_IN_W    = 8,
    parameter   BASE_DIR        = "/home/superior/AutoEncoder_FPGA",
    parameter   MEM_DIR         = "/design/mem_file",
    parameter   ACT_FILE        = "/tanh_mem.txt"     ,
    parameter   WEIGHT_FILE_PFX = "/weight_mem_",
    parameter   BIAS_FILE_PFX   = "/bias_mem_",
    parameter   LAYER_IDX       = "0",
    parameter   NEURON_IDX      = "0"
)(
    input                   clk     ,
    input                   rst_n   ,
    input   [INPUT_W-1:0]   in_dat  ,      
    input                   in_valid,//successive
    output  [OUTPUT_W-1:0]  out_dat ,
    output                  out_valid
);

localparam  CALC_W = WEIGHT_W + INPUT_W;
reg [$clog2(WEIGHT_NUM)-1:0] cnt;

wire [WEIGHT_W-1:0]     weight;
reg  [INPUT_W-1:0]      in_dat_d;
wire [CALC_W-1:0]       mul;
reg  [CALC_W-1:0]       mul_d;
wire [CALC_W-1:0]       num_sel;
wire [CALC_W-1:0]       add_result;
reg  [CALC_W-1:0]       sum;
wire [CALC_W-1-8:0]     sum_short;
reg  [BIAS_W-1:0]       bias [0:0];
wire [ACT_IN_W-1:0]     act_in;

wire weight_valid;
reg  sum_valid;
wire sel;
wire eop;
reg  eop_d1;
reg  eop_d2;
reg  eop_d3;
(*keep = "true"*) reg  biasaddr =0;
//RESERVED PLAN-------------------------------------------------------------------------------------
// 函数定义
// function [7:0] to_ascii;
//     input [6:0] number; // 输入范围为 0 到 99，7 位可以表示最大值 99
//     begin
//         // 将数字转换为 ASCII 码
//         if (number < 10) begin
//             to_ascii = number + "0"; // 对于 0-9，返回对应的 ASCII 码
//         end else begin
//             to_ascii = (number / 10) + "0"; // 十位数
//             to_ascii = {to_ascii, (number % 10) + "0"}; // 个位数
//         end
//     end
// endfunction
// localparam WEIGHT_FILE = {WEIGHT_FILE_PFX,to_ascii(LAYER_IDX),"_",to_ascii(NEURON_IDX),".txt"};
// localparam BIAS_FILE   = {BIAS_FILE_PFX  ,to_ascii(LAYER_IDX),"_",to_ascii(NEURON_IDX),".txt"};
//---------------------------------------------------------------------------------------------------
localparam WEIGHT_FILE = {WEIGHT_FILE_PFX,LAYER_IDX,"_",NEURON_IDX,".txt"};
localparam BIAS_FILE   = {BIAS_FILE_PFX  ,LAYER_IDX,"_",NEURON_IDX,".txt"};
//-----------control logic------------------//
assign eop = (cnt == WEIGHT_NUM-1);
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        cnt <= 'd0;    
    end
    else if(eop)begin
        cnt <= 1'b0;
    end
    else if(in_valid)begin
        cnt <= cnt + 1'b1;
    end
end
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        {sum_valid,eop_d3,eop_d2,eop_d1} <= 4'b0000;
    end
    else begin
        {sum_valid,eop_d3,eop_d2,eop_d1} <= {eop_d3,eop_d2,eop_d1,eop};
    end
end
assign sel = eop_d3;
///////////////////////////////////////////////

localparam BIAS_PATH = {BASE_DIR,MEM_DIR,BIAS_FILE};
initial begin
    $readmemb(BIAS_PATH,bias);
end

always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        in_dat_d <= 'd0;    
    end
    else if(in_valid)begin
        in_dat_d <= in_dat;
    end
end

weight_memory#(
    .WEIGHT_NUM (WEIGHT_NUM ),
    .WEIGHT_W   (WEIGHT_W   ),
    .BASE_DIR   (BASE_DIR   ),
    .MEM_DIR    (MEM_DIR    ),
    .WEIGHT_FILE(WEIGHT_FILE)
)u_weight_memory(
    .clk         (clk        ),
    .addr        (cnt        ),
    .ren         (in_valid   ),
    .weight      (weight     ),
    .weight_valid(weight_valid) 
);

assign mul = $signed(weight) * $signed(in_dat_d);

always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        mul_d <= 'd0;
    end
    else if(weight_valid)begin
        mul_d <= mul;
    end
    else begin
        mul_d <= 'd0;
    end
end

assign num_sel = sel?{{(CALC_W-BIAS_W){bias[biasaddr][BIAS_W-1]}},bias[biasaddr]}:mul_d;//!!!dont modify
assign add_result = $signed(num_sel) + $signed(sum);

always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        sum <= 'd0;
    end
    else if(sum_valid)begin
        sum <= 'd0;
    end
    //FIXME:overflow and under protection
    // else if(!num_sel[CALC_W-1]&!sum[CALC_W-1]&add_result[CALC_W-1])begin//overflow
    //     sum <= {1'b0,{(CALC_W-1){1'b1}}};
    // end
    // else if(num_sel[CALC_W-1&sum[CALC_W-1]&!add_result[CALC_W-1])begin//underflow
    //     sum <= {1'b1,{(CALC_W-1){1'b0}}};
    // end
    else begin
        sum <= add_result;
    end
end
assign sum_short = sum[CALC_W-1:8];

assign act_in = ($signed(sum_short) >= $signed({{2'b01},{(2*WEIGHT_W-10){1'b1}}}) )?{1'b0,{(WEIGHT_W-1){1'b1}}}:
                ($signed(sum_short) <= $signed({{2'b10},{(2*WEIGHT_W-10){1'b0}}}) )?{1'b1,{(WEIGHT_W-1){1'b0}}}:
                sum_short[WEIGHT_W-1:0];
//act in -2.000 ~ +1.999
tanh_calc u_tanh_calc(
    .rst_n      (rst_n    ),
    .clk        (clk      ),
    .in_x       (act_in   ),
    .in_valid   (sum_valid),
    .out_y      (out_dat  ),
    .out_valid  (out_valid) 
);


// tanh_calc#(
//     .IN_DAT_W   (ACT_IN_W ),
//     .OUT_DAT_W  (WEIGHT_W ),
//     .BASE_DIR   (BASE_DIR ),
//     .MEM_DIR    (MEM_DIR  ),
//     .MEM_FILE   (ACT_FILE )
// )u_tanh_calc(
//     .clk        (clk      ),
//     .in_x       (act_in   ),
//     .in_valid   (sum_valid),
//     .out_y      (out_dat  ),
//     .out_valid  (out_valid)  
// );

endmodule