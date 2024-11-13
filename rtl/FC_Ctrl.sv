module FC_Ctrl#(
    parameter DIM_INPUT  = 96, 
    parameter DIM_OUTPUT = 8, 
    parameter INPUT_W    = 16,
    parameter OUTPUT_W   = 8,  
    parameter BRAM_DAT_W = 64,
    parameter BRAM_ADDR_W= 32,
    parameter BATCH_NUM  = 10
)(
    input   wire                        clk         ,
    input   wire                        rst_n       ,
    //
    input   wire                        fc_out_vld  ,
    output  reg                         fc_in_vld   ,  
    output  reg   [INPUT_W-1:0]         fc_in_dat   ,      
    input   wire  [OUTPUT_W-1:0]        fc_out_dat [DIM_OUTPUT-1:0],
    //
    input   wire   [BRAM_ADDR_W-1:0]    bc_addr     ,
    input   wire                        bc_en       ,
    input   wire   [7:0]                bc_we       ,
    //
    input   wire   [BRAM_DAT_W -1:0]    fc_dout     ,
    output  wire   [BRAM_DAT_W -1:0]    fc_din      ,
    output  wire   [BRAM_ADDR_W-1:0]    fc_addr     ,
    output  reg                         fc_en       ,
    output  reg    [7:0]                fc_we       ,
    //
    input   wire                        axi_ar_ready,
    input   wire                        axi_ar_valid,
    input   wire                        axi_aw_valid,
    input   wire                        axi_aw_ready,
    //
    output  reg                         bc_load_ready_ar,
    output  reg                         bc_load_ready_r
       
);

//128kB BRAM addr range from 0x0000 - 0x1FFFF
//DIN_REGION:       0x00000 - 0x1EFFF(124kB)
//RESULT_REGION:    0x1F000 - 0x1FFFF(4kB)
localparam  ADDR_INC = BRAM_DAT_W / 8;
localparam  FC_LOAD_BASE  = 'h0000;
localparam  FC_STORE_BASE = 'h3400;
localparam  FC_LOAD_LAST_ADDR   = FC_LOAD_BASE + BATCH_NUM * DIM_INPUT * INPUT_W / 8 - ADDR_INC;
localparam  FC_STORE_LAST_ADDR  = FC_STORE_BASE + BATCH_NUM * DIM_OUTPUT * OUTPUT_W / 8 -ADDR_INC;

localparam  BC_STORE    = 3'b000;
localparam  BC_STORE_OK = 3'b001;
localparam  FC_LOAD     = 3'b010;
localparam  FC_STORE    = 3'b011;
localparam  FC_STORE_OK = 3'b100;
localparam  BC_LOAD     = 3'b101;

wire    bc_store_last;
// wire    bc_load_last;
wire    fc_store_last;
wire    bc_load_ready;
reg     [BRAM_ADDR_W-1:0] fc_rd_addr;
reg     [BRAM_ADDR_W-1:0] fc_wr_addr;
reg     [2:0] cstate,nstate;
wire    fc_store_done;
wire    fc_read_done;

reg     [3:0]  fc_store_cnt;
reg     [10:0] fc_load_cnt ; 

wire    fc_rd_addr_inc;

reg     [OUTPUT_W*DIM_OUTPUT-1:0]  fc_out_dat_r;

assign fc_addr = (&fc_we)?fc_wr_addr:fc_rd_addr;

assign bc_store_last = (&bc_we)     & bc_en & (bc_addr == FC_LOAD_LAST_ADDR );
// assign bc_load_last  = (~(&bc_we))  & bc_en & (bc_addr == FC_STORE_LAST_ADDR);
assign fc_store_last = (&fc_we)     & fc_en & (fc_addr == FC_STORE_LAST_ADDR);

assign bc_load_ready = (cstate == FC_STORE_OK);
/////////////////////////////////////////////////////
//MAIN FSM
////////////////////////////////////////////////////


always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        cstate <= BC_STORE;
    end
    else begin
        cstate <= nstate;
    end
end 

always@(*) begin
    case (cstate)
        BC_STORE:begin
            nstate =  bc_store_last?BC_STORE_OK:BC_STORE;
        end 
        BC_STORE_OK:begin
            nstate =  FC_LOAD;            
        end
        FC_LOAD:begin
            nstate =  fc_out_vld?FC_STORE:FC_LOAD;
        end    
        FC_STORE:begin
            nstate =  fc_store_done?fc_store_last?FC_STORE_OK:FC_LOAD:FC_STORE;         
        end
        FC_STORE_OK:begin
            nstate =  BC_LOAD;
        end 
        BC_LOAD:begin
            nstate =  (axi_aw_valid&axi_aw_ready)?BC_STORE:BC_LOAD;
        end    
        default:begin
            nstate = BC_STORE;
        end
    endcase
end

//fc_rd_addr ,fc_wr_addr, fc_en ,fc_we
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        fc_rd_addr <= FC_LOAD_BASE;
        fc_wr_addr <= FC_STORE_BASE;
        fc_en      <= 1'b0;
        fc_we      <= 8'b0;
    end
    else if(cstate == BC_STORE_OK)begin 
        fc_rd_addr <= FC_LOAD_BASE;
        fc_wr_addr <= FC_STORE_BASE;
        fc_en      <= 1'b1;
        fc_we      <= 8'b0;      
    end
    else if(cstate == FC_LOAD)begin
        if(nstate == FC_STORE)begin
            fc_we <= 8'b1111_1111;
            fc_en <= 1'b1;
        end
        else if(fc_read_done)begin
            fc_en <= 1'b0;
        end
        else if(fc_rd_addr_inc)begin
            fc_rd_addr <= fc_rd_addr + ADDR_INC;
        end
    end
    else if(cstate == FC_STORE)begin
        if(nstate == FC_STORE_OK)begin
            fc_we <= 8'b0;
            fc_en <= 1'b0;
        end
        else begin
            fc_en      <= 1'b1;
            fc_we      <= 8'b0; 
            fc_wr_addr<= fc_wr_addr + ADDR_INC;
        end      
    end
end

///////////////////////////////////////
//FC store loop
///////////////////////////////////////
localparam FC_STORE_DONE_CYCLE = (DIM_OUTPUT * OUTPUT_W +  BRAM_DAT_W -1)/ BRAM_DAT_W;//手动向上取整
genvar i;
generate
    for(i=0;i<DIM_OUTPUT;i=i+1)begin
        always @(posedge clk) begin
            if(fc_out_vld)begin
                    fc_out_dat_r[i*OUTPUT_W+:OUTPUT_W] <= fc_out_dat[i][OUTPUT_W-1:0];
            end
        end        
    end
endgenerate


assign fc_din = fc_out_dat_r[fc_store_cnt*64+:64];
assign fc_store_done = (cstate == FC_STORE) && (fc_store_cnt == FC_STORE_DONE_CYCLE-1);
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        fc_store_cnt <= 'd0;
    end
    else if(cstate == FC_STORE)begin
        fc_store_cnt <= fc_store_cnt + 1'b1;
    end
    else begin
        fc_store_cnt <= 'd0;
    end
end

///////////////////////////////////////
//FC load loop
///////////////////////////////////////
localparam FC_READ_DONE_CYCLE = DIM_INPUT;
assign fc_read_done = (cstate == FC_LOAD) && (fc_load_cnt == FC_READ_DONE_CYCLE-1);
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        fc_load_cnt <= 'd0;
    end
    else if(fc_read_done)begin
        fc_load_cnt <= 'd0;
    end
    else if(cstate == FC_LOAD)begin
        fc_load_cnt <= fc_load_cnt + 1'b1;
    end
    else begin
        fc_load_cnt <= 'd0;
    end
end
assign fc_rd_addr_inc = (fc_load_cnt[1:0] == 2'b11);
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        fc_in_vld <= 1'b0;
    end
    else if(cstate == FC_LOAD)begin
        fc_in_vld <= fc_en;
    end
    else begin
        fc_in_vld <= 1'b0;
    end
end
always@(*) begin
    if(cstate == FC_LOAD)begin
        case (fc_load_cnt[1:0])
            2'b01:fc_in_dat = fc_dout[0*16+:16];
            2'b10:fc_in_dat = fc_dout[1*16+:16];
            2'b11:fc_in_dat = fc_dout[2*16+:16];
            2'b00:fc_in_dat = fc_dout[3*16+:16]; 
        endcase        
    end
    else begin
        fc_in_dat = 'd0;
    end

end

///////////////////////////////////////////////
//AXI block logic
///////////////////////////////////////////////
always @(posedge clk,negedge rst_n) begin
    if(~rst_n)begin
        bc_load_ready_ar <= 1'b0;
        bc_load_ready_r  <= 1'b0;
    end
    else if(bc_load_ready)begin
        bc_load_ready_ar <= 1'b1;
        bc_load_ready_r  <= 1'b0;
    end
    else if(~bc_load_ready_r)begin
        if(axi_ar_valid&axi_ar_ready)begin
            bc_load_ready_r <= 1'b1;
        end
    end
    else if(cstate != BC_LOAD)begin
        bc_load_ready_ar <= 1'b0;
        bc_load_ready_r  <= 1'b0;        
    end
end


endmodule