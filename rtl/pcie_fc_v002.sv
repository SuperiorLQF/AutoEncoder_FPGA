module pcie_fc_v002 (
    input   CLK_IN_D_0_clk_n,
    input   CLK_IN_D_0_clk_p,
    input   sys_rst_n_0     ,
    output  user_lnk_up_0   ,
    input   pcie_mgt_0_rxn  ,
    input   pcie_mgt_0_rxp  ,
    output  pcie_mgt_0_txn  ,
    output  pcie_mgt_0_txp  
);
//=============================================================================
//param def
//=============================================================================
localparam DIM_INPUT  = 96;
localparam DIM_OUTPUT = 8;//neuron number
localparam WEIGHT_W   = 8;
localparam INPUT_W    = 16;
localparam OUTPUT_W   = 8;
localparam BASE_DIR         = "/home/superior/AutoEncoder_FPGA";
localparam MEM_DIR          = "/output/mem_file";
localparam ACT_FILE         = "/tanh_mem.txt";
localparam WEIGHT_FILE_PFX  = "/weight_mem_";
localparam BIAS_FILE_PFX    = "/bias_mem_";
localparam CLK_FRE          = 200;      //clock frequency(Mhz)
localparam BAUD_RATE        = 115200;   //UART baud rate
localparam BRAM_DAT_W       = 64;
localparam BRAM_ADDR_W      = 14;
localparam BATCH_NUM        = 320;//10
localparam ADDR_MW          = 17;
localparam ADDR_SW          = ADDR_MW -3 ;
wire  [INPUT_W-1:0]   fc_dat_i  ;      
wire                  fc_vld_i;
wire  [OUTPUT_W-1:0]  fc_dat_o [DIM_OUTPUT-1:0];
wire                  fc_vld_o;
wire [ADDR_MW-1:0]bc_addr;
wire bc_en;
wire bc_we;
wire [ADDR_SW-1:0]fc_addr;
wire [31:0]fc_din;
wire [31:0]fc_dout;
wire fc_en;
wire fc_we;
wire axi_ar_ready;
wire axi_ar_valid;
wire axi_aw_ready;
wire axi_aw_valid;
wire bc_load_ready_ar;
wire bc_load_ready_r;
wire axi_aresetn_0; 
wire axi_aclk_0;  
//============BD sys=====================//
system_wrapper SYS
   (
    .CLK_IN_D_0_clk_n   (CLK_IN_D_0_clk_n ),
    .CLK_IN_D_0_clk_p   (CLK_IN_D_0_clk_p ),
    .axi_aclk_0         (axi_aclk_0       ),
    .axi_ar_ready       (axi_ar_ready     ),
    .axi_ar_valid       (axi_ar_valid     ),
    .axi_aresetn_0      (axi_aresetn_0    ),
    .axi_aw_ready       (axi_aw_ready     ),
    .axi_aw_valid       (axi_aw_valid     ),
    .bc_addr            (bc_addr          ),
    .bc_en              (bc_en            ),
    .bc_load_ready_ar   (bc_load_ready_ar ),
    .bc_load_ready_r    (bc_load_ready_r  ),
    .bc_we              (bc_we            ),
    .fc_addr            (fc_addr          ),
    .fc_din             (fc_din           ),
    .fc_dout            (fc_dout          ),
    .fc_en              (fc_en            ),
    .fc_we              (fc_we            ),
    .pcie_mgt_0_rxn     (pcie_mgt_0_rxn   ),
    .pcie_mgt_0_rxp     (pcie_mgt_0_rxp   ),
    .pcie_mgt_0_txn     (pcie_mgt_0_txn   ),
    .pcie_mgt_0_txp     (pcie_mgt_0_txp   ),
    .sys_rst_n_0        (sys_rst_n_0      ),
    .user_lnk_up_0      (user_lnk_up_0    )
    );
///////////////////////////////////////////

//============FC Layer==================//
FC_Layer#(
    .DIM_INPUT       (DIM_INPUT       ),
    .DIM_OUTPUT      (DIM_OUTPUT      ),
    .WEIGHT_W        (WEIGHT_W        ),
    .LAYER_IDX       ("0"             ),
    .BASE_DIR        (BASE_DIR        ),
    .MEM_DIR         (MEM_DIR         ),
    .WEIGHT_FILE_PFX (WEIGHT_FILE_PFX ),
    .BIAS_FILE_PFX   (BIAS_FILE_PFX   )
)U_FC(
    .clk      (axi_aclk_0),
    .rst_n    (axi_aresetn_0),
    .in_dat   (fc_dat_i),
    .in_valid (fc_vld_i),
    .out_dat  (fc_dat_o),
    .out_valid(fc_vld_o)
);
///////////////////////////////////////////

//===========FC CTRL=======================//
FC_Ctrl#(
    .DIM_INPUT  (DIM_INPUT  ), 
    .DIM_OUTPUT (DIM_OUTPUT ),
    .INPUT_W    (INPUT_W    ),
    .OUTPUT_W   (OUTPUT_W   ), 
    .BRAM_DAT_W (BRAM_DAT_W ),
    .BRAM_ADDR_W(BRAM_ADDR_W),
    .ADDR_MW    (ADDR_MW    ),
    .ADDR_SW    (ADDR_SW    ),
    .BATCH_NUM  (BATCH_NUM  )
)U_FC_Ctrl(
    .clk                (axi_aclk_0     ),
    .rst_n              (axi_aresetn_0  ),
    .fc_out_vld         (fc_vld_o       ),
    .fc_in_vld          (fc_vld_i       ),  
    .fc_in_dat          (fc_dat_i       ),      
    .fc_out_dat         (fc_dat_o       ),
    .bc_addr            (bc_addr        ),
    .bc_en              (bc_en          ),
    .bc_we              (bc_we          ),
    .fc_dout            (fc_dout        ),
    .fc_din             (fc_din         ),
    .fc_addr            (fc_addr        ),
    .fc_en              (fc_en          ),
    .fc_we              (fc_we          ),
    .axi_ar_ready       (axi_ar_ready    ),    
    .axi_ar_valid       (axi_ar_valid    ),    
    .axi_aw_valid       (axi_aw_valid    ),    
    .axi_aw_ready       (axi_aw_ready    ),       
    .bc_load_ready_ar   (bc_load_ready_ar),
    .bc_load_ready_r    (bc_load_ready_r )
       
);
///////////////////////////////////////////
endmodule