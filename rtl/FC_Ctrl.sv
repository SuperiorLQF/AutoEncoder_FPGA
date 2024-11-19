module FC_Ctrl#(
    parameter DIM_INPUT  = 96, 
    parameter DIM_OUTPUT = 8, 
    parameter INPUT_W    = 16,
    parameter OUTPUT_W   = 8,  
    parameter BRAM_DAT_W = 64,
    parameter BRAM_ADDR_W= 32,
    parameter ADDR_MW    = 15,
    parameter ADDR_SW    = 12,
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
    (*mark_debug = "true"*)input   wire   [ADDR_MW-1:0]        bc_addr     ,
    (*mark_debug = "true"*)input   wire                        bc_en       ,
    (*mark_debug = "true"*)input   wire                        bc_we       ,
    //
    (*mark_debug = "true"*)input   wire   [31:0]               fc_dout     ,
    (*mark_debug = "true"*)output  wire   [31:0]               fc_din      ,
    (*mark_debug = "true"*)output  wire   [ADDR_SW-1:0]        fc_addr     ,
    (*mark_debug = "true"*)output  reg                         fc_en       ,
    (*mark_debug = "true"*)output  reg                         fc_we       ,
    //
    input   wire                        axi_ar_ready,
    input   wire                        axi_ar_valid,
    input   wire                        axi_aw_valid,
    input   wire                        axi_aw_ready,
    //
    output  reg                         bc_load_ready_ar,
    output  reg                         bc_load_ready_r
       
);

/////////////////////////////////////////////////////
//32KB BRAM Controller interface
//0x0000 - 0x7FFF 64bit DATA WIDTH
//DIN_REGION:       0x0000 - 0x67FF (26KB)
//RESULT_REGION:    0x6800 - 0x7FFF (6KB)
/////////////////////////////////////////////////////
localparam  BC_STORE_BASE       = 'h0000;
localparam  BC_STORE_ADDR_INC   = 64 / 8;
localparam  BC_STORE_LAST_ADDR  = BC_STORE_BASE + BATCH_NUM * DIM_INPUT * 32 / 8 - BC_STORE_ADDR_INC;


//////////////////////////////////////////////////////
//16kB BRAM addr range from 0x000 - 0xFFF(32BIT 编址)
//DIN_REGION:       0x000 - 0xCFF(13kB)
//RESULT_REGION:    0xD00 - 0xFFF(3kB)
//////////////////////////////////////////////////////
localparam  FC_LOAD_BASE        = 'h000;
localparam  FC_STORE_BASE       = 'hd00;
localparam  FC_LOAD_ADDR_INC    =  1;
localparam  FC_STORE_ADDR_INC   =  1;
localparam  FC_STORE_LAST_ADDR  = FC_STORE_BASE + BATCH_NUM * DIM_OUTPUT / 2 -FC_STORE_ADDR_INC;


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
reg     [ADDR_SW-1:0] fc_rd_addr;
reg     [ADDR_SW-1:0] fc_wr_addr;
reg     [2:0] cstate,nstate;
wire    fc_store_done;
wire    fc_read_done;
wire    fc_rd_addr_inc;
reg     [3:0]  fc_store_cnt;
reg     [10:0] fc_load_cnt ; 

reg     [OUTPUT_W*DIM_OUTPUT-1:0]  fc_out_dat_r;

assign fc_addr = fc_we?fc_wr_addr:fc_rd_addr;

assign bc_store_last = bc_we    & bc_en & (bc_addr == BC_STORE_LAST_ADDR );

assign fc_store_last = fc_we    & fc_en & (fc_addr == FC_STORE_LAST_ADDR);

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
        fc_we      <= 1'b0;
    end
    else if(cstate == BC_STORE_OK)begin 
        fc_rd_addr <= FC_LOAD_BASE;
        fc_wr_addr <= FC_STORE_BASE;
        fc_en      <= 1'b1;
        fc_we      <= 1'b0;      
    end
    else if(cstate == FC_LOAD)begin
        if(nstate == FC_STORE)begin
            fc_we <= 1'b1;
            fc_en <= 1'b1;
        end
        else if(fc_read_done)begin
            fc_en <= 1'b0;
            fc_rd_addr <= fc_rd_addr + FC_LOAD_ADDR_INC;
        end
        else if(fc_rd_addr_inc)begin
            fc_rd_addr <= fc_rd_addr + FC_LOAD_ADDR_INC;
        end
    end
    else if(cstate == FC_STORE)begin
        if(nstate == FC_STORE_OK)begin
            fc_we <= 1'b0;
            fc_en <= 1'b0;
        end
        else if(nstate == FC_LOAD)begin
            fc_en      <= 1'b1;
            fc_we      <= 1'b0; 
            fc_wr_addr<= fc_wr_addr + FC_STORE_ADDR_INC;
        end   
        else begin
            fc_en      <= 1'b1;
            fc_we      <= 1'b1; 
            fc_wr_addr<= fc_wr_addr + FC_STORE_ADDR_INC;            
        end   
    end
end

///////////////////////////////////////
//FC store loop
///////////////////////////////////////
localparam FC_STORE_DONE_CYCLE = DIM_OUTPUT / 2;
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


assign fc_din = {   8'b0000_0000,
                    fc_out_dat_r[fc_store_cnt*16+8+:8],
                    8'b0000_0000,
                    fc_out_dat_r[fc_store_cnt*16+:8]};

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
    else if((cstate == FC_LOAD)&fc_en)begin
        fc_load_cnt <= fc_load_cnt + 1'b1;
    end
    else begin
        fc_load_cnt <= 'd0;
    end
end
assign fc_rd_addr_inc = fc_load_cnt[0];
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
        case (fc_load_cnt[0])
            1'b1:fc_in_dat = fc_dout[0*16+:16];
            1'b0:fc_in_dat = fc_dout[1*16+:16];
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