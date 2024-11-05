module sys_top_nouart(
    input   sys_clk_p,
    input   sys_clk_n,
    input   rst_n,
    output  fan,
    input   rx_data_valid,
    input   [7:0] rx_data,
    output  uart_tx
);
//=============================================================================
//param def
//=============================================================================
localparam DIM_INPUT  = 96;
localparam DIM_OUTPUT = 8;//neuron number
localparam WEIGHT_W   = 8;
localparam BASE_DIR         = "/home/superior/AutoEncoder_FPGA";
localparam MEM_DIR          = "/output/mem_file";
localparam ACT_FILE         = "/tanh_mem.txt";
localparam WEIGHT_FILE_PFX  = "/weight_mem_";
localparam BIAS_FILE_PFX    = "/bias_mem_";
localparam CLK_FRE          = 200;      //clock frequency(Mhz)
localparam BAUD_RATE        = 115200;   //UART baud rate

//=============================================================================
//sig def
//=============================================================================
logic  [WEIGHT_W-1:0]  fc_dat_i;
(*keep = "true"*)logic  [WEIGHT_W-1:0]  fc_dat_o [DIM_OUTPUT-1:0];
logic  fc_vld_i;
(*keep = "true"*)logic  fc_vld_o;
logic  [$clog2(DIM_OUTPUT)-1:0] pop_cnt;
(*keep = "true"*)logic  [7:0] tx_data;
(*keep = "true"*)logic  tx_data_valid;
logic  [6:0] fifo_d_count;
logic  fifo_rd_en;
logic  fifo_rd_en_d1;
logic  fifo_rd_en_tmp;
logic  fifo_empty;

//===========================================================================
//Differentia system clock to single end clock
//===========================================================================
logic   clk;
assign  fan = 1'b0;
IBUFGDS u_ibufg_sys_clk(
    .I  (sys_clk_p),            
    .IB (sys_clk_n),          
    .O  (clk      )        
);  

//=============FIFO======================//
rx_fifo rx_fifo_inst(
    .clk(clk),
    .srst(~rst_n),
    .data_count(fifo_d_count),
    .wr_en(rx_data_valid),
    .din(rx_data),
    .rd_en(fifo_rd_en),
    .dout(fc_dat_i),
    .empty(fifo_empty)
);

//////////////////////////////////////////



//============FC_PUSH====================//
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        fifo_rd_en_tmp <= 1'b0;
    end
    else if(fifo_d_count == DIM_INPUT)begin
        fifo_rd_en_tmp <= 1'b1;
    end
    else if(fifo_empty)begin
        fifo_rd_en_tmp <= 1'b0;
    end
end
assign fifo_rd_en = fifo_rd_en_tmp & (~fifo_empty);
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        fc_vld_i <= 1'b0;
        fifo_rd_en_d1 <= 1'b0;
    end
    else begin
        fc_vld_i <= fifo_rd_en_d1;
        fifo_rd_en_d1 <= fifo_rd_en;
    end
end
//////////////////////////////////////////



//============FC Layer==================//
FC_Layer#(
    .DIM_INPUT       (DIM_INPUT       ),
    .DIM_OUTPUT      (DIM_OUTPUT      ),
    .WEIGHT_W        (WEIGHT_W        ),
    .LAYER_IDX       ("0"             ),
    .BASE_DIR        (BASE_DIR        ),
    .MEM_DIR         (MEM_DIR         ),
    .ACT_FILE        (ACT_FILE        ),
    .WEIGHT_FILE_PFX (WEIGHT_FILE_PFX ),
    .BIAS_FILE_PFX   (BIAS_FILE_PFX   )
)U_FC(
    .clk      (clk),
    .rst_n    (rst_n),
    .in_dat   (fc_dat_i),
    .in_valid (fc_vld_i),
    .out_dat  (fc_dat_o),
    .out_valid(fc_vld_o)
);
///////////////////////////////////////////




//==========FC POP========================//
always @(posedge clk ,negedge rst_n) begin
    if(~rst_n)begin
        pop_cnt <= 'd0; 
    end
    else if(trans_done & (pop_cnt == DIM_OUTPUT-1))begin
        pop_cnt <= 'd0;
    end
    else if(trans_done)begin
        pop_cnt <= pop_cnt + 1'b1;
    end
end
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        tx_data_valid <= 1'b0;
    end
    else if(fc_vld_o)begin
        tx_data_valid <= 1'b1;
    end
    else if(trans_done & (pop_cnt == DIM_OUTPUT-1))begin
        tx_data_valid <= 1'b0;
    end
end
assign tx_data = fc_dat_o[pop_cnt];
/////////////////////////////////////////////


//==========UART_TX======================//
uart_tx#(
	.CLK_FRE     (CLK_FRE   ),
	.BAUD_RATE   (BAUD_RATE )
)
U_TX(
	.clk            (clk),  
	.rst_n          (rst_n),  
	.tx_data        (tx_data),  
	.tx_data_valid  (tx_data_valid),  
	.tx_data_ready  (),  
	.tx_pin         (uart_tx),  
	.trans_done     (trans_done)
);
///////////////////////////////////////////

endmodule
