//*********************
//version 1.0.0
//*********************
module mvm_pe#(
    parameter DOP_VV        = 8'd32,
    parameter BIAS_W        = 15,
    parameter WEIGHT_W      = 8,
    parameter VVMAC_IN_W    = 16,
    parameter VVMAC_OUT_W   = 17
)(
    //clk rst---------------------------------------
    input           clk     ,
    input           rst_n   ,
    //instruction interface-------------------------
    input           valid   ,
    output  reg     ready   ,
    input   [79:0]  instruction,
    //data input------------------------------------
    input       [15:0]  din_dat ,
    output              din_rd  ,
    output  reg [15:0]  din_addr,
    //data output-----------------------------------
    output      [15:0]  dout_dat,
    output              dout_we ,
    output  reg [15:0]  dout_addr,
    //weight input----------------------------------
    input   [DOP_VV*WEIGHT_W-1:0]  weight_dat ,
    output                      weight_rd  ,
    output  reg [11:0]          weight_addr,
    //bias input------------------------------------
    input   [DOP_VV*BIAS_W-1:0] bias_dat ,
    output                      bias_rd  ,
    output  reg [9:0]           bias_addr
);
wire ready_event;
wire init_ok,mac_ok,layer_ok;

reg [8:0]   Col_current,Col_remain,Col_current_r;

reg [3:0]   OP;
reg [8:0]   DIMi,DIMo,DIMo_r;
reg [9:0]   BiasBaseAddr;
reg [11:0]  WeightBaseAddr;
reg [15:0]  DioBaseAddr;

wire first_init;

reg [2:0]   cstate,nstate;
localparam  IDLE     = 3'b000;    
localparam  INIT     = 3'b001;
localparam  MAC      = 3'b010;
localparam  SAVE     = 3'b011; 

genvar i;
wire vvmac_sel,vvmac_en_tmp0,vvmac_en,vvmac_clr;
reg  vvmac_en_tmp1;
wire vvmac_en_reg_ahead;
wire [VVMAC_IN_W-1:0] vvmac_din;
wire [DOP_VV*VVMAC_OUT_W-1:0] vvmac_dout;  
reg  [DOP_VV*VVMAC_OUT_W-1:0] vvmac_dout_r;

reg  [8:0] xin_cnt;
wire xin_ready;
reg  [8:0] save_cnt;

wire [VVMAC_OUT_W-1:0] af_i;
wire [VVMAC_IN_W-1 :0] af_o;
reg  af_valid;
reg  [$clog2(DOP_VV)-1:0] af_addr;
reg  [1:0] din_sel_short,din_sel_short_r;
wire [1:0] din_sel;

wire din_fifo_empty;
wire din_fifo_nempty;
wire din_fifo_rd;
wire din_fifo_wr;
wire [VVMAC_IN_W-1:0] din_fifo_dato;

wire repeat_fifo_empty;
wire repeat_fifo_nempty;
wire repeat_fifo_rd;
wire repeat_fifo_wr;
wire [VVMAC_IN_W-1:0] repeat_fifo_dato;

//1.instruction parse============================================ 
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        OP              <= 'd0;
        DIMi            <= 'd0;
        DIMo            <= 'd0;
        BiasBaseAddr    <= 'd0;
        WeightBaseAddr  <= 'd0;
        DioBaseAddr     <= 'd0;
    end
    else if(valid&ready)begin
        OP              <= instruction[79:76];
        DIMi            <= instruction[63:56] + 1'b1;
        DIMo            <= instruction[55:48] + 1'b1;
        BiasBaseAddr    <= instruction[41:32];
        WeightBaseAddr  <= instruction[27:16];
        DioBaseAddr     <= instruction[15: 0];        
    end
end
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        ready <= 1'b1;
    end
    else if(ready&valid)begin
        ready <= 1'b0;
    end
    else if(ready_event)begin
        ready <= 1'b1;
    end
end
//=============================================================

//2.Controller===================================================
//FSM
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        cstate <= IDLE;
    end
    else begin
        cstate <= nstate;
    end
end
always @(*) begin
    case (cstate)
        IDLE:begin
            nstate = (ready&valid)?INIT:IDLE;
        end
        INIT:begin
            nstate = (init_ok)?(OP==4'h3)?SAVE:MAC:INIT;
        end
        MAC :begin
            nstate = (mac_ok)?(layer_ok)?IDLE:INIT:MAC;
        end
        SAVE:begin
            nstate = (save_ok)?IDLE:SAVE;
        end 
        default: begin
            nstate = IDLE;
        end
    endcase
end

//Flags
assign ready_event  = (cstate == IDLE);
assign init_ok      = (cstate == INIT);
assign mac_ok       = (xin_cnt== DIMi+1)&&(cstate == MAC); 
assign save_ok      = (save_cnt == DIMo - 1'b1);
assign layer_ok     = (Col_remain == 'd0) & mac_ok;

//Remain Matrix piece
assign first_init = (cstate == INIT)&&(Col_current=='d0);
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        Col_current <= 'd0;
        Col_remain  <= 'd0;
    end
    else if(cstate == IDLE)begin
        Col_current <= 'd0;
        Col_remain  <= 'd0;        
    end
    else if(cstate == INIT)begin
        if(Col_current=='d0)begin //first time
           Col_current <= (DIMo>DOP_VV)?DOP_VV       :DIMo   ;
           Col_remain  <= (DIMo>DOP_VV)?(DIMo-DOP_VV):'d0    ;
        end
        else begin
           Col_current <= (Col_remain>DOP_VV)?DOP_VV :Col_remain     ;
           Col_remain  <= (Col_remain>DOP_VV)?(Col_remain-DOP_VV):'d0;            
        end
    end
end

always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        xin_cnt <= 'd0;
    end
    else if((cstate == IDLE) || (cstate == INIT))begin
        xin_cnt <= 'd0;
    end
    else if(vvmac_en)begin
        xin_cnt <= xin_cnt + 1'b1;
    end
end

//weight_addr
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        weight_addr <= 'd0;
    end
    else if(first_init)begin
        weight_addr <= WeightBaseAddr;
    end
    else if(vvmac_en_reg_ahead)begin
        weight_addr <= weight_addr + 1'b1;
    end
end
//bias_addr
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        bias_addr <= 'd0;
    end
    else if(first_init)begin
        bias_addr <= BiasBaseAddr;
    end
    else if(cstate == INIT)begin
        bias_addr <= bias_addr + 1'b1;
    end
end
//dout addr
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        dout_addr <= 'd0;
    end
    else if((cstate == INIT)&&(nstate == SAVE))begin
        dout_addr <= DioBaseAddr;
    end
    else if(cstate == SAVE)begin
        dout_addr <= dout_addr + 2'd2;
    end
end
assign dout_we = (cstate == SAVE);
//din addr
assign din_rd = (cstate!= SAVE);
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        din_addr <= 'd0;
    end
    else if(first_init)begin
        din_addr <= DioBaseAddr;
    end
    else if(vvmac_en_reg_ahead&(din_sel==2'b00))begin
        din_addr <= din_addr + 2'd2;//Din dat is 2Byte
    end
end


always@(posedge clk,negedge rst_n)begin
    if(~rst_n)begin
        vvmac_en_tmp1 <= 1'b0;
    end
    else begin
        vvmac_en_tmp1 <= vvmac_en_tmp0;
    end
end
assign vvmac_sel        = (xin_cnt== DIMi)?1'b1:1'b0;
assign vvmac_en_tmp0    = (cstate==MAC) && xin_ready;
assign vvmac_en         = vvmac_en_tmp0 & vvmac_en_tmp1;
assign vvmac_clr = mac_ok;
assign vvmac_en_reg_ahead = vvmac_en_tmp0 && (xin_cnt<DIMi-1);

assign xin_ready = (din_sel==2'b00) || (din_sel==2'b01)&&(din_fifo_nempty) || (din_sel==2'b10)&&(repeat_fifo_nempty) || vvmac_sel;

assign din_fifo_rd      =    (vvmac_en & (din_sel==2'b01)) || (cstate==SAVE);
assign din_fifo_wr      =    af_valid;
assign repeat_fifo_rd   =    vvmac_en & (din_sel==2'b10) & (~vvmac_sel)&(~vvmac_clr);
assign repeat_fifo_wr   =    vvmac_en & (Col_remain!='d0) & (~vvmac_sel)&(~vvmac_clr);

always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        save_cnt <= 'd0;
    end
    else if(cstate == SAVE)begin
        save_cnt <= save_cnt + 1'b1;
    end
    else if(cstate == IDLE)begin
        save_cnt <= 'd0;
    end
end

assign bias_rd = 1'b1;
assign weight_rd = 1'b1;
//3.Vector-Vector MAC PE Group===================================
generate
    for(i=0;i<DOP_VV;i=i+1)begin
        vv_mac_pe#(
            .INPUT_W    (VVMAC_IN_W  ),
            .WEIGHT_W   (WEIGHT_W    ),
            .BIAS_W     (BIAS_W      ),
            .OUTPUT_W   (VVMAC_OUT_W ),
            .OVERLFOW_W (9   )
        )u_vv_mac_pe(
            .clk     (clk   ),
            .rst_n   (rst_n ),
            .din     (vvmac_din                              ),   
            .bias    (bias_dat[i*BIAS_W+:BIAS_W]             ),   
            .weight  (weight_dat[i*WEIGHT_W+:WEIGHT_W]       ),   
            .sel     (vvmac_sel   ),
            .en      (vvmac_en    ),   
            .clr     (vvmac_clr   ),   
            .dout    (vvmac_dout[i*VVMAC_OUT_W+:VVMAC_OUT_W] )    
        );        
    end
endgenerate
//output register
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        vvmac_dout_r <= 'd0;
    end
    else if(mac_ok)begin
        vvmac_dout_r <= vvmac_dout;
    end
end

//=============================================================

//AF===========================================================
tanh_af#(
    .VVMAC_IN_W  (VVMAC_IN_W ),
    .VVMAC_OUT_W (VVMAC_OUT_W)
) u_tanh_af(
    .afi(af_i),
    .afo(af_o)
);
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        af_valid <= 1'b0;
        Col_current_r <= 'd0;
    end
    else if(mac_ok)begin
        af_valid <= 1'b1;
        Col_current_r   <= Col_current;
    end
    else if(af_addr==Col_current_r-1)begin
        af_valid <= 1'b0;
    end
end
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        af_addr <= 'd0;
    end
    else if(af_valid)begin
        af_addr <= af_addr + 1'b1;
    end
    else begin
        af_addr <= 'd0;
    end
end
assign af_i = vvmac_dout_r[af_addr*VVMAC_OUT_W+:VVMAC_OUT_W];
//=============================================================

//Din sel=====================================================
//Dinfifo
fifo16x256 u_dinfifo(
    .clk    (clk    ),
    .rst    (~rst_n ),
    .din    (af_o   ),
    .wr_en  (din_fifo_wr    ),
    .full   (),
    .dout   (din_fifo_dato  ),
    .rd_en  (din_fifo_rd    ),
    .empty  (din_fifo_empty ),
    .data_count()
);
assign din_fifo_nempty = ~din_fifo_empty;


//Repeatfifo
fifo16x256 u_repeatfifo(
    .clk    (clk                ),
    .rst    (~rst_n             ),
    .din    (vvmac_din          ),
    .wr_en  (repeat_fifo_wr     ),
    .full   (),
    .dout   (repeat_fifo_dato   ),
    .rd_en  (repeat_fifo_rd     ),
    .empty  (repeat_fifo_empty  ),
    .data_count()
);
assign repeat_fifo_nempty = ~repeat_fifo_empty;

//select
assign vvmac_din = (din_sel==2'b00)?din_dat:(din_sel==2'b01)?din_fifo_dato:repeat_fifo_dato;
always @(*) begin
    if(cstate == INIT)begin
        if(Col_current=='d0)begin//first time
            din_sel_short = (OP==4'h2)?2'b01:2'b00;
        end  
        else begin
            din_sel_short = 2'b10;
        end
    end
    else begin
        din_sel_short = 2'b00;
    end
end
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        din_sel_short_r <= 2'b00;
    end
    else if(cstate==INIT)begin
        din_sel_short_r <= din_sel_short;
    end
end
assign din_sel = (cstate==INIT)?din_sel_short:din_sel_short_r;
//=============================================================

endmodule