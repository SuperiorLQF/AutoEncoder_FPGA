module FC_Layer#(
    parameter DIM_INPUT  = 96,
    parameter DIM_OUTPUT = 8,//neuron number
    parameter INPUT_W    = 16,
    parameter OUTPUT_W   = 8,
    parameter WEIGHT_W   = 8,
    parameter BIAS_W     = 15,
    parameter LAYER_IDX         = "",
    parameter BASE_DIR          = "/home/superior/BCI_compression",
    parameter MEM_DIR           = "/design/mem_file",
    parameter ACT_FILE          = "/tanh_mem.txt",
    parameter WEIGHT_FILE_PFX   = "/weight_mem_",
    parameter BIAS_FILE_PFX     = "/bias_mem_"
)(
    input                   clk     ,
    input                   rst_n   ,
    input   [INPUT_W-1:0]   in_dat  ,      
    input                   in_valid,
    output  [OUTPUT_W-1:0]  out_dat [DIM_OUTPUT-1:0],
    output                  out_valid
);

neuron#(
    .WEIGHT_NUM (DIM_INPUT),
    .INPUT_W    (INPUT_W  ),
    .WEIGHT_W   (WEIGHT_W ),
    .BIAS_W     (BIAS_W   ),
    .OUTPUT_W   (OUTPUT_W ),
    .ACT_IN_W   (WEIGHT_W ),
    .BASE_DIR   (BASE_DIR ),
    .MEM_DIR    (MEM_DIR  ),
    .ACT_FILE   (ACT_FILE ),
    .WEIGHT_FILE_PFX    (WEIGHT_FILE_PFX),
    .BIAS_FILE_PFX      (BIAS_FILE_PFX  ),
    .LAYER_IDX          (LAYER_IDX),
    .NEURON_IDX         ("0")
)u_neuron_0(
    .clk       (clk),
    .rst_n     (rst_n),
    .in_dat    (in_dat),      
    .in_valid  (in_valid),
    .out_dat   (out_dat[0]),
    .out_valid (out_valid) 
);    

neuron#(
    .WEIGHT_NUM (DIM_INPUT),
    .INPUT_W    (INPUT_W  ),
    .WEIGHT_W   (WEIGHT_W ),
    .BIAS_W     (BIAS_W   ),
    .OUTPUT_W   (OUTPUT_W ),
    .ACT_IN_W   (WEIGHT_W ),
    .BASE_DIR   (BASE_DIR ),
    .MEM_DIR    (MEM_DIR  ),
    .ACT_FILE   (ACT_FILE ),
    .WEIGHT_FILE_PFX    (WEIGHT_FILE_PFX),
    .BIAS_FILE_PFX      (BIAS_FILE_PFX  ),
    .LAYER_IDX          (LAYER_IDX),
    .NEURON_IDX         ("1")
)u_neuron_1(
    .clk       (clk),
    .rst_n     (rst_n),
    .in_dat    (in_dat),      
    .in_valid  (in_valid),
    .out_dat   (out_dat[1]),
    .out_valid () 
);

neuron#(
    .WEIGHT_NUM (DIM_INPUT),
    .INPUT_W    (INPUT_W  ),
    .WEIGHT_W   (WEIGHT_W ),
    .BIAS_W     (BIAS_W   ),
    .OUTPUT_W   (OUTPUT_W ),
    .ACT_IN_W   (WEIGHT_W ),
    .BASE_DIR   (BASE_DIR ),
    .MEM_DIR    (MEM_DIR  ),
    .ACT_FILE   (ACT_FILE ),
    .WEIGHT_FILE_PFX    (WEIGHT_FILE_PFX),
    .BIAS_FILE_PFX      (BIAS_FILE_PFX  ),
    .LAYER_IDX          (LAYER_IDX),
    .NEURON_IDX         ("2")
)u_neuron_2(
    .clk       (clk),
    .rst_n     (rst_n),
    .in_dat    (in_dat),      
    .in_valid  (in_valid),
    .out_dat   (out_dat[2]),
    .out_valid () 
);

neuron#(
    .WEIGHT_NUM (DIM_INPUT),
    .INPUT_W    (INPUT_W  ),
    .WEIGHT_W   (WEIGHT_W ),
    .BIAS_W     (BIAS_W   ),
    .OUTPUT_W   (OUTPUT_W ),
    .ACT_IN_W   (WEIGHT_W ),
    .BASE_DIR   (BASE_DIR ),
    .MEM_DIR    (MEM_DIR  ),
    .ACT_FILE   (ACT_FILE ),
    .WEIGHT_FILE_PFX    (WEIGHT_FILE_PFX),
    .BIAS_FILE_PFX      (BIAS_FILE_PFX  ),
    .LAYER_IDX          (LAYER_IDX),
    .NEURON_IDX         ("3")
)u_neuron_3(
    .clk       (clk),
    .rst_n     (rst_n),
    .in_dat    (in_dat),      
    .in_valid  (in_valid),
    .out_dat   (out_dat[3]),
    .out_valid () 
);

neuron#(
    .WEIGHT_NUM (DIM_INPUT),
    .INPUT_W    (INPUT_W  ),
    .WEIGHT_W   (WEIGHT_W ),
    .BIAS_W     (BIAS_W   ),
    .OUTPUT_W   (OUTPUT_W ),
    .ACT_IN_W   (WEIGHT_W ),
    .BASE_DIR   (BASE_DIR ),
    .MEM_DIR    (MEM_DIR  ),
    .ACT_FILE   (ACT_FILE ),
    .WEIGHT_FILE_PFX    (WEIGHT_FILE_PFX),
    .BIAS_FILE_PFX      (BIAS_FILE_PFX  ),
    .LAYER_IDX          (LAYER_IDX),
    .NEURON_IDX         ("4")
)u_neuron_4(
    .clk       (clk),
    .rst_n     (rst_n),
    .in_dat    (in_dat),      
    .in_valid  (in_valid),
    .out_dat   (out_dat[4]),
    .out_valid () 
);

neuron#(
    .WEIGHT_NUM (DIM_INPUT),
    .INPUT_W    (INPUT_W  ),
    .WEIGHT_W   (WEIGHT_W ),
    .BIAS_W     (BIAS_W   ),
    .OUTPUT_W   (OUTPUT_W ),
    .ACT_IN_W   (WEIGHT_W ),
    .BASE_DIR   (BASE_DIR ),
    .MEM_DIR    (MEM_DIR  ),
    .ACT_FILE   (ACT_FILE ),
    .WEIGHT_FILE_PFX    (WEIGHT_FILE_PFX),
    .BIAS_FILE_PFX      (BIAS_FILE_PFX  ),
    .LAYER_IDX          (LAYER_IDX),
    .NEURON_IDX         ("5")
)u_neuron_5(
    .clk       (clk),
    .rst_n     (rst_n),
    .in_dat    (in_dat),      
    .in_valid  (in_valid),
    .out_dat   (out_dat[5]),
    .out_valid () 
);

neuron#(
    .WEIGHT_NUM (DIM_INPUT),
    .INPUT_W    (INPUT_W  ),
    .WEIGHT_W   (WEIGHT_W ),
    .BIAS_W     (BIAS_W   ),
    .OUTPUT_W   (OUTPUT_W ),
    .ACT_IN_W   (WEIGHT_W ),
    .BASE_DIR   (BASE_DIR ),
    .MEM_DIR    (MEM_DIR  ),
    .ACT_FILE   (ACT_FILE ),
    .WEIGHT_FILE_PFX    (WEIGHT_FILE_PFX),
    .BIAS_FILE_PFX      (BIAS_FILE_PFX  ),
    .LAYER_IDX          (LAYER_IDX),
    .NEURON_IDX         ("6")
)u_neuron_6(
    .clk       (clk),
    .rst_n     (rst_n),
    .in_dat    (in_dat),      
    .in_valid  (in_valid),
    .out_dat   (out_dat[6]),
    .out_valid () 
);

neuron#(
    .WEIGHT_NUM (DIM_INPUT),
    .INPUT_W    (INPUT_W  ),
    .WEIGHT_W   (WEIGHT_W ),
    .BIAS_W     (BIAS_W   ),
    .OUTPUT_W   (OUTPUT_W ),
    .ACT_IN_W   (WEIGHT_W ),
    .BASE_DIR   (BASE_DIR ),
    .MEM_DIR    (MEM_DIR  ),
    .ACT_FILE   (ACT_FILE ),
    .WEIGHT_FILE_PFX    (WEIGHT_FILE_PFX),
    .BIAS_FILE_PFX      (BIAS_FILE_PFX  ),
    .LAYER_IDX          (LAYER_IDX),
    .NEURON_IDX         ("7")
)u_neuron_7(
    .clk       (clk),
    .rst_n     (rst_n),
    .in_dat    (in_dat),      
    .in_valid  (in_valid),
    .out_dat   (out_dat[7]),
    .out_valid () 
);
endmodule
