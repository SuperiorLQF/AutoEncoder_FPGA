'''
请先切换到su,安装库请用su或sudo进行安装,目标编译器是/usr/bin/python3
使用前先编译和加载xdma内核驱动
'''
import struct
import numpy as np
# from fixedpoint import FixedPoint
import time
import random
import numpy as np


def _generate_hex_from_np(i_samples):
    return b"".join(struct.pack('f',input_float) 
                    for point in i_samples 
                    for input_float in point)

def _generate_np_from_hex(recv_data,output_dim):
        recv_data_str = recv_data.hex()
        recv_dara_str_lst = [recv_data_str[i:i+8] for i in range(0,len(recv_data_str),8)]
        float_1D = []
        for item in recv_dara_str_lst:
            item_byes = bytes.fromhex(item)
            float_1D.append(struct.unpack('f',item_byes)[0])
        lst_2d = [float_1D[i:i+output_dim] for i in range(0, len(float_1D), output_dim)] 
        o_samples = np.array(lst_2d)
        return o_samples

def _pcie_send(device_path,hex_bytes):
    with open(device_path, 'r+b') as device_file:
        # 写入设备
        device_file.write(hex_bytes)

def _pcie_recv(device_path,size,offset):
    with open(device_path, 'rb') as device_file:
        # 读取指定大小的数据
        device_file.seek(offset)
        data = device_file.read(size)
        return data

# 将字节数据保存到文件
def _save_to_file(file_path, data):
    with open(file_path, 'wb') as file:
        file.write(data)



'''
----------------@function@----------------------------------------------------
calculate fc layer on FPGA

----------------@input@-------------------------------------------------------
i_samples
2d numpy array
dim = N * M 
[point_0 point_1 ... point_N-1],while point_X = [input_0 input_1 ... input_M-1]
M is also AutoEncoder FC Layer's input Dimension
in this case,N<=50(suggested:10),M=96

----------------@output@-------------------------------------------------------
o_samples
2d numpy array
dim = N * Q
[point_0 point_1 ... point_N-1],while point_X = [output_0 output_1 ... output_Q-1]
Q is also AutoEncoder FC Layer's output Dimension

'''
def fc_batch_cal(i_samples,
                 test = True,
                 result_offset_addr = 0x0000,
                 h2c_device_file_path='/dev/xdma0_h2c_0',
                 c2h_device_file_path='/dev/xdma0_c2h_0'):
    ###########################################
    if(test == True):
        # 记录开始时间
        start_time = time.perf_counter()
    ###########################################

    batch_num   = i_samples.shape[0]
    input_dim   = i_samples.shape[1]
    output_dim  = 8
    recv_size   = output_dim * batch_num * 4

    #turn i_samples into hex format
    send_data   = _generate_hex_from_np(i_samples)

    #pcie send
    _pcie_send(h2c_device_file_path,send_data)

    #pcie recv
    recv_data   =_pcie_recv(c2h_device_file_path,recv_size,result_offset_addr)

    #turn received data into nyarray
    o_samples   = _generate_np_from_hex(recv_data,output_dim)

    ###########################################
    if(test == True):
        # 记录结束时间
        end_time = time.perf_counter()
        # 计算并输出执行时间
        execution_time = end_time - start_time
        print(f"Execution time: {execution_time} seconds")
    ###########################################

    ###########################################
    if(test == True):
        # 保存到 send.bin 文件
        _save_to_file('../output/send.bin', send_data)
        # 保存到 recv.bin 文件
        _save_to_file('../output/recv.bin', recv_data)
    ###########################################

    return o_samples

def soft_verify(test_in,test_out):
    threshold_err = 0.01
    print('-'*50)
    print(f"\33[1;7;32m{'Compare Procedure':^50}\33[0m")
    print('-'*50)    
    bias        = np.load('../etc/encoder.0.bias.npy')
    weights     = np.load('../etc/encoder.0.weight.npy')
    bias_R      = bias.reshape(-1,1)
    for i in range(test_in.shape[0]):
        test_in_T = test_in[i].reshape(-1,1)
        mac = weights @ test_in_T + bias_R
        result = np.tanh(mac).reshape(-1)
        err = np.sum(np.square(result - test_out[i]))
        if(err>=threshold_err):
            print(f"\33[1;31mCOMPARE_FAIL\33[0m in NO.{i} point")

            print('reference value is : ')
            print("\33[1m",end='')
            print(result)
            print("\33[0m",end='')
            print('WHILE recv value is : ')
            print("\33[1m",end='')
            print(test_out[i])
            print("\33[0m",end='')
            print('-'*50)
        else:
            print(f"\33[1;32mNO.{i} COMPARE_PASS\33[0m")
def fc_batch_cal_320(   i_samples,
                        test = True,
                        result_offset_addr = 0x0000,
                        h2c_device_file_path='/dev/xdma0_h2c_0',
                        c2h_device_file_path='/dev/xdma0_c2h_0'):
    ###########################################
    if(test == True):
        # 记录开始时间
        start_time = time.perf_counter()
    ###########################################

    result_lst =[]
    for i in range(32):
        test_in_sml  = i_samples[i*10:i*10+10]
        test_out_sml = fc_batch_cal(
                                            i_samples=test_in_sml,
                                            test=False,
                                            result_offset_addr=result_offset_addr,
                                            h2c_device_file_path = h2c_device_file_path,
                                            c2h_device_file_path = c2h_device_file_path
                                        )
        result_lst.append(test_out_sml)

    result_array = np.vstack(result_lst)

    ###########################################
    if(test == True):
        # 记录结束时间
        end_time = time.perf_counter()
        # 计算并输出执行时间
        execution_time = end_time - start_time
        soft_verify(i_samples,result_array)
        print(f"Execution time: {execution_time} seconds")
    ###########################################
     
    return result_array

if __name__ == "__main__":
    random.seed(40)
    test_in = np.array([[random.uniform(-1,1) for _ in range(96)] for __ in range(320)])
    test_out= fc_batch_cal_320(
        i_samples=test_in,
        test=True,
        result_offset_addr= 0x6800
    )

''' kernel driver example
# 将十六进制字符串写入设备文件
def write_to_device(device_path, hex_string):
    with open(device_path, 'r+b') as device_file:
        # 将十六进制字符串转换为字节数据
        byte_data = bytes.fromhex(hex_string)
        # 写入设备
        device_file.write(byte_data)

# 从设备文件读取数据
def read_from_device(device_path, size,offset):
    with open(device_path, 'rb') as device_file:
        # 读取指定大小的数据
        device_file.seek(offset)
        data = device_file.read(size)
        return data
'''