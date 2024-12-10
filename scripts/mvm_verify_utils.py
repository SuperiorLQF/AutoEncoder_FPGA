from enum import Enum
import numpy as np
from fixedpoint import FixedPoint
class TEST_CONDITION(Enum):
    sim  = 1
    test = 2

# 生成正态分布数据
def generate_random_matrix(row,col,mean,thresh_abs,std_dev):

    data = np.random.normal(mean, std_dev, row*col)
    data = np.clip(data, -thresh_abs, thresh_abs)
    data = data.reshape(row,col)
    return data

#正态随机化多层dense layer din/weight/bias并存为npy
def generate_random_layer_param(layer_cfg,seed=0):
    np.random.seed(seed)
    idx = 0
    for layer_cfg_item in layer_cfg:
        if(idx==0):
            din    = generate_random_matrix(1,layer_cfg_item[0],0,2,0.5)
            np.save("../output/tmp/din.npy",din)
        weight = generate_random_matrix(layer_cfg_item[0],layer_cfg_item[1],0,1,0.2)
        bias   = generate_random_matrix(1,layer_cfg_item[1],0,1,0.2)
        np.save(f"../output/tmp/weight_{idx}.npy",weight)
        np.save(f"../output/tmp/bias_{idx}.npy",bias)
        idx += 1


#读取npy并转为float和fxp元祖，元祖第一个元素是float构成的numpy，第二个元素是FXP str构成的numpy
def npy2fxp(layer_cfg,fxp_cfg):
    result_dic ={}
    din  = np.load("../output/tmp/din.npy")
    din  = din.reshape(-1)
    din_fxp=[FixedPoint(item, 
                         signed=True,
                         m=fxp_cfg['din'][0],
                         n=fxp_cfg['din'][1],
                         str_base=2,
                         overflow='clamp',
                         overflow_alert='ignore') for item in din]
    result_dic['din'] = (np.array([float(item) for item in din_fxp]).reshape(1,layer_cfg[0][0]),
                         np.array([str(item) for item in din_fxp]).reshape(1,layer_cfg[0][0])
                         )
    for idx in range(len(layer_cfg)):
        weight = np.load(f"../output/tmp/weight_{idx}.npy")
        weight = weight.reshape(-1)
        bias   = np.load(f"../output/tmp/bias_{idx}.npy")
        bias   = bias.reshape(-1)
        weight_fxp=[FixedPoint(item, 
                            signed=True,
                            m=fxp_cfg['weight'][0],
                            n=fxp_cfg['weight'][1],
                            str_base=2,
                            overflow='clamp',
                            overflow_alert='ignore') for item in weight]        
        bias_fxp  =[FixedPoint(item, 
                            signed=True,
                            m=fxp_cfg['bias'][0],
                            n=fxp_cfg['bias'][1],
                            str_base=2,
                            overflow='clamp',
                            overflow_alert='ignore') for item in bias]
        result_dic[f'weight_{idx}'] =   (np.array([float(item) for item in weight_fxp]).reshape(layer_cfg[idx][0],layer_cfg[idx][1]),
                                         np.array([str(item) for item in weight_fxp]).reshape(layer_cfg[idx][0],layer_cfg[idx][1])
                                        )
        result_dic[f'bias_{idx}']   =   (np.array([float(item) for item in bias_fxp]).reshape(1,layer_cfg[idx][1]),
                                         np.array([str(item) for item in bias_fxp]).reshape(1,layer_cfg[idx][1])
                                        )      
    return result_dic

#将FXP str的BIAS和WEIGHT按照格式存储为MEM初始化文件，主要是倒序操作，并存储为txt
def WeightAndBias_Reshape(matrix,fxp_cfg,idx,WorB='weight'):
    FillZero = '0'*(fxp_cfg[WorB][0]+fxp_cfg[WorB][1])
    shape_row,shape_column=matrix.shape
    piece_num     = shape_column //32
    column_remain = shape_column % 32
    if(piece_num==0):
        pass
    else:
        result = matrix[:,0:32]
        i=0
        for i in range(1,piece_num):
            piece  = matrix[:,i*32:(i+1)*32]
            result = np.concatenate((result, piece), axis=0)
    if(column_remain==0):
        pass
    else:
        if(piece_num!=0):
            i=i+1
            piece  = np.concatenate((matrix[:,i*32:],np.array([FillZero for _ in range(shape_row*(32-column_remain))]).reshape(shape_row,(32-column_remain))),axis=1)
            result = np.concatenate((result, piece), axis=0)
        else:
            result = np.concatenate((matrix[:,0:],np.array([FillZero for _ in range(shape_row*(32-column_remain))]).reshape(shape_row,(32-column_remain))),axis=1)
    # result_tmp0 = np.flip(result,axis=1)
    result_tmp0 = result[:,::-1]
    result_tmp1 = [''.join(row) for row in  result_tmp0]
    return result_tmp1


#将整个test_data_dict保存为FXP的txt供mem读取,同时输出每一层读取的基地址
def save_test_dict2txt(test_data_dict,layer_cfg,fxp_cfg):
    base_addr_lst=[]
    weight_base_addr = 0
    bias_base_addr   = 0

    din_str = test_data_dict['din'][1].reshape(-1)
    with open("../output/tmp/din.txt",'w') as f:
         f.write('\n'.join(din_str))  # Write din strings to din.txt
    weight_str_lst =[]
    bias_str_lst   =[]
    for idx in range(len(layer_cfg)):
        base_addr_lst.append((hex(weight_base_addr)[2:],hex(bias_base_addr)[2:]))

        weight_str_npy      = test_data_dict[f"weight_{idx}"][1]
        weight_str_reorder  = WeightAndBias_Reshape(weight_str_npy,fxp_cfg,idx,'weight')
        weight_str_lst.append('\n'.join(weight_str_reorder))

        bias_str_npy        = test_data_dict[f"bias_{idx}"][1]
        bias_str_reorder    = WeightAndBias_Reshape(bias_str_npy,fxp_cfg,idx,'bias')
        bias_str_lst.append('\n'.join(bias_str_reorder))

        weight_base_addr += len(weight_str_reorder) 
        bias_base_addr   += len(bias_str_reorder)
    print("mem address info:",base_addr_lst)
    with open(f"../output/tmp/weight_mem.txt",'w') as f:
        f.write('\n'.join(weight_str_lst))  # Write to weight txt   
    with open(f"../output/tmp/bias_mem.txt",'w') as f:
        f.write('\n'.join(bias_str_lst))  # Write to weight txt     

#soft model计算验证
def verify_dense_layer(test_data_dict,layer_cfg,debug_layer=-1,debug_vv_col=-1):
    din_fp      = test_data_dict['din'][0]
    for idx in range(len(layer_cfg)):
        weight_fp   = test_data_dict[f"weight_{idx}"][0]
        bias_fp     = test_data_dict[f"bias_{idx}"][0]
        z = np.dot(din_fp,weight_fp) + bias_fp
        output = np.tanh(z)
        output_str = output.astype(str).reshape(-1).tolist()
        with open(f'../output/tmp/gold_result_{idx}.txt','w') as f:
            f.write('\n'.join(output_str))
        if ((debug_vv_col>=0) and (debug_layer==idx)):
            print(f"\33[1;7;32m D E B U G    I N F O   (layer={debug_layer},pe={debug_vv_col})\33[0m")
            print('-'*60)
            print(f"{'cnt':<10}  {'din':<30} * {'weight':<10} = {'result':<15} ")
            print('-'*60)
            din_vec     = din_fp[0]
            weight_vec  = weight_fp[:,debug_vv_col] 
            bias_scalar = bias_fp[0][debug_vv_col]
            mac_result  = 0
            for i in range(len(din_vec)):
                mac_result += din_vec[i]*weight_vec[i]
                print(f"{i:<10}+ {din_vec[i]:<30} * {weight_vec[i]:<10} = {mac_result:<15} ")
            mac_result += bias_scalar
            dbg_result  = np.tanh(mac_result)
            print('-'*60)
            print(f"  {'bias':<18} = {'result':<15} ")
            print('-'*60)
            print(f"+ {bias_scalar:<18} = {mac_result:<15}")
            print('-'*60)
            print(f"{'tanh_result':<18}")
            print('-'*60)
            print(f"{dbg_result:<18}")
            print()
        din_fp = output