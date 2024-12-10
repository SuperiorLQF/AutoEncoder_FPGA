`timescale 1ns/100ps
module tb_mvm_pe;
localparam DOP_VV        = 8'd32;
localparam BIAS_W        = 15;
localparam WEIGHT_W      = 8;
localparam VVMAC_IN_W    = 16;
localparam VVMAC_OUT_W   = 17;
//clk rst---------------------------------------
logic                   clk     ;
logic                   rst_n   ;
//instruction interface-------------------------
logic                   valid   ;
logic                   ready   ;
logic   [79:0]          instruction;
//data logic------------------------------------
logic   [15:0]          din_dat ;
logic                   din_rd  ;
logic   [15:0]          din_addr;
//data logic -----------------------------------
logic   [15:0]          dout_dat;
logic                   dout_we ;
logic   [15:0]          dout_addr;
//weight logic----------------------------------
logic   [DOP_VV*WEIGHT_W-1:0]  weight_dat ;
logic                   weight_rd  ;
logic   [11:0]          weight_addr;
//bias logic------------------------------------
logic   [DOP_VV*BIAS_W-1:0] bias_dat ;
logic                   bias_rd  ;
logic   [9:0]           bias_addr;

bit [79:0] instr_queue [$];
bit [15:0] check_queue [$];
bit [15:0] check_dim_i_queue[$];
bit [15:0] check_dim_o_queue[$];

logic [15:0]        din_mem    [31:0]; 
logic [8*32-1:0]    weight_mem [655:0];
logic [15*32-1:0]   bias_mem   [8:0];
initial begin
    $readmemb("/home/superior/AutoEncoder_FPGA/output/tmp/din.txt",din_mem);
    $readmemb("/home/superior/AutoEncoder_FPGA/output/tmp/weight_mem.txt",weight_mem);
    $readmemb("/home/superior/AutoEncoder_FPGA/output/tmp/bias_mem.txt",bias_mem);
end



/////////////////////U S E R   H I N T ///////////////////
enum {IDLE,INIT, MAC ,SAVE} hint_state;
assign hint_state = (dut.cstate==3'b000)?IDLE:(dut.cstate==3'b001)?INIT:(dut.cstate==3'b010)?MAC:SAVE;
bit num_plus_tmpt;
integer hint_layer_num=0;  
always @(posedge clk) begin
    if(dut.first_init)begin
        if(dut.OP != 4'h3)begin
            $display("MVM %0d x %0d",dut.DIMi,dut.DIMo,$time);            
        end
        else begin
            $display("SAVE TO 1 x %0d",dut.DIMo,$time);
        end 
        check_dim_o_queue.push_back(dut.DIMo);
        check_dim_i_queue.push_back(dut.DIMi);

        if(num_plus_tmpt&&dut.OP!=4'h3)begin
            hint_layer_num ++;
        end
        else begin
            hint_layer_num = 1'b0;
        end
    end
    if(dut.layer_ok)begin
        num_plus_tmpt = 1'b1;
    end
end
////////////////////////////////////////////////////////


////////////////////C H E C K E R ///////////////////////
integer file;
real  gold_result;
string line;
bit [15:0] check_result_fxp;
real check_result_float;
real error;
string flag;
bit [7:0] layer_idx=0;
string gold_result_dir;
string layer_idx_str;
always @(posedge clk) begin
    if(dut.din_fifo_wr)begin
        check_queue.push_back(dut.af_o);
        if(check_queue.size==check_dim_o_queue[0])begin//check
            $display("%s",{60{"-"}});
            $display("MVM %0d x %0d Check Reslut (layer%0d)",check_dim_i_queue[0],check_dim_o_queue[0],layer_idx);
            $display("%s",{60{"-"}});   
            $display("%4s|%10s|%10s|%10s|%8s","Idx","Ref","Mon","ERR","P/F");
            $display("%s",{60{"-"}});   
            if(check_dim_i_queue[0]!=0)begin//check for the first layer//FIXME
                layer_idx_str = $sformatf("%0d",layer_idx);
                gold_result_dir = {"/home/superior/AutoEncoder_FPGA/output/tmp/gold_result_",layer_idx_str,".txt"};
                file = $fopen(gold_result_dir,"r");
                if(file)begin
                    foreach(check_queue[i])begin
                        check_result_fxp = check_queue[i];
                        if(check_result_fxp[15])begin
                            check_result_float = (~check_result_fxp[14:0]+1'b1) / -128.0;
                        end
                        else begin
                            check_result_float = check_result_fxp / 128.0;
                        end
                        $fscanf(file,"%f\n",gold_result);
                        error = (gold_result-check_result_float)**2;
                        if(error > 0.01)begin
                            flag = "FAIL";
                        end
                        else begin
                            flag = "PASS";
                        end
                        $display("%4d|%10f|%10f|%10f|%8s",i,gold_result,check_result_float,error,flag);
                        if(flag == "FAIL")begin
                            #1000
                            $stop;
                        end

                    end
                end
                $fclose(file);
                layer_idx ++;
            end

            check_dim_o_queue.pop_front();
            check_dim_i_queue.pop_front();
            check_queue.delete();
        end
    end
end


mvm_pe dut(.*);

always #20 clk <= ~clk;
initial begin
    clk     <= 1'b0;
    rst_n   <= 1'b0;
    instr_queue.push_back(80'h1000_1F63_0000_0000_0000);//dimi32,dimo100
    instr_queue.push_back(80'h2000_637F_0004_0080_0000);//dimi100,dimo128
    instr_queue.push_back(80'h2000_7F07_0008_0210_0000);//dimi128,dimo8
    instr_queue.push_back(80'h3000_0007_0000_0000_0000);//dimo8,save
    valid   <= 1'b0;
    //release rst_n
    #2000
    rst_n <= 1'b1; 
    #2000//FIXME  
    valid <= 1'b1;
    wait(dut.save_ok);
    $display("SAVE OK",$time);
    valid <= 1'b0;
    #2000
    $finish;
end
initial begin
    instruction <= instr_queue.pop_front();
    while(1)begin
        @(posedge clk);
        if(valid&ready)begin
            $display("INSTRUCTION EXECUTING: %h",instruction,$time);
            instruction <= instr_queue.pop_front();
        end        
    end


end
initial begin
    din_dat <= 'd0;
    weight_dat <= 'd0;
    bias_dat <= 'd0;
end
//zero delay model
// assign din_dat    = din_mem[din_addr/2];
// assign weight_dat = weight_mem[weight_addr];
// assign bias_dat   = bias_mem[bias_addr];
//1 delay model
always @(posedge clk) begin
    if(din_rd)begin
        din_dat <= din_mem[din_addr/2];
    end
end
always @(posedge clk) begin
    if(weight_rd)begin
        weight_dat <= weight_mem[weight_addr];
    end
end
always @(posedge clk) begin
    if(bias_rd)begin
        bias_dat <= bias_mem[bias_addr];
    end
end

//verify mac ok
//when mac ok, push number into fifo 
//when mac ok & layer ok ,push number into fifo, and then verify all number in fifo
endmodule