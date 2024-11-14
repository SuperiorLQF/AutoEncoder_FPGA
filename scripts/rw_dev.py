'''
请先切换到su,安装库请用su或sudo进行安装,目标编译器是/usr/bin/python3
使用前先编译和加载xdma内核驱动
'''
import os
import numpy as np
from fixedpoint import FixedPoint
import time



def _generate_hex_from_np(i_samples):
    str_lst = []
    for point in i_samples:
        for input_float in point:
            input_fix_obj = FixedPoint( input_float,
                            signed=True,
                            m=9,
                            n=7,
                            str_base = 16,
                            overflow = 'clamp',
                            overflow_alert = 'warning')
            input_fix_obj_str = str(input_fix_obj) #这个是大端的结果，因为方便人眼看，是把高字节放在了前面（低位）
            input_fix_str = input_fix_obj_str[2:] + input_fix_obj_str[0:2] #交换一下高低字节，变成小端
            str_lst.append(input_fix_str)
    hex_string = "".join(str_lst)
    hex_bytes  = bytes.fromhex(hex_string)
    return hex_bytes

def _generate_np_from_hex(recv_data,output_dim):
        hex_str = recv_data.hex()
        substrings1 = [hex_str[i:i+2] for i in range(0, len(hex_str), 2)]
        sub_float = []
        for item in substrings1:
            output_fix_obj = FixedPoint( '0x'+item,
                            signed=True,
                            m=1,
                            n=7,
                            str_base = 16,
                            overflow = 'clamp',
                            overflow_alert = 'warning')
            sub_float.append(float(output_fix_obj))
        lst_2d = [sub_float[i:i+output_dim] for i in range(0, len(sub_float), output_dim)] 
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
                 result_offset_addr = 0x3400,
                 h2c_device_file_path='/dev/xdma0_h2c_0',
                 c2h_device_file_path='/dev/xdma0_c2h_0'):
    batch_num   = i_samples.shape[0]
    input_dim   = i_samples.shape[1]
    output_dim  = 8
    recv_size   = output_dim * batch_num

    #turn i_samples into hex format
    send_data   = _generate_hex_from_np(i_samples)

    ###########################################
    if(test == True):
        # 记录开始时间
        start_time = time.perf_counter()
    ###########################################

    #pcie send
    _pcie_send(h2c_device_file_path,send_data)
    #pcie recv
    recv_data   =_pcie_recv(c2h_device_file_path,recv_size,result_offset_addr)

    ###########################################
    if(test == True):
        # 记录结束时间
        end_time = time.perf_counter()
        # 计算并输出执行时间
        execution_time = end_time - start_time
        print(f"Execution time: {execution_time} seconds")
    ###########################################

    #turn received data into nyarray
    o_samples   = _generate_np_from_hex(recv_data,output_dim)

    ###########################################
    if(test == True):
        # 保存到 send.bin 文件
        _save_to_file('../output/send.bin', send_data)
        # 保存到 recv.bin 文件
        _save_to_file('../output/recv.bin', recv_data)
        print(o_samples)
    ###########################################

    return o_samples
    
if __name__ == "__main__":
    fc_batch_cal(
        i_samples=np.array([[0.5 for _ in range(96)] for __ in range(10)]),
        test=True
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