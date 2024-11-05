'''
windows请先安装CP210X驱动;
Linux先modprobe加载serial ko驱动

串口通讯库:pip install pyserial   
定点数计算库:pip install fixedpoint
'''
import serial
from fixedpoint import FixedPoint
#######################################################################################
#GLOBAL CONFIG:use utils.FIXCFG 
#######################################################################################
class config:
    def __init__(self,
                 input_width             = 16,
                 input_fraction_width    = 7,
                 weight_width            = 8,
                 weight_fraction_width   = 7,
                 bias_width              = 15,
                 bias_fraction_width     = 14,):
        self.Input_W        = input_width
        self.Input_Frac_W   = input_fraction_width
        self.Weight_W       = weight_width         
        self.Weight_Frac_W  = weight_fraction_width
        self.Bias_W         = bias_width           
        self.Bias_Frac_W    = bias_fraction_width  
    def max_i_value(self,):
        max_i_bin_str="0"+"1"*(self.Input_W -1)
        a = FixedPoint('0b'+max_i_bin_str,
                       signed=True,
                       m=self.Input_W - self.Input_Frac_W,
                       n=self.Input_Frac_W,
                       str_base=2,
                       overflow='clamp',
                       overflow_alert='warning')
        return a
    def min_i_value(self,):
        min_i_bin_str="1"+"0"*(self.Input_W -1)
        a = FixedPoint('0b'+min_i_bin_str,
                       signed=True,
                       m=self.Input_W - self.Input_Frac_W,
                       n=self.Input_Frac_W,
                       str_base=2,
                       overflow='clamp',
                       overflow_alert='warning')
        return a
FIXCFG = config()    
#######################################################################################
#deprecated!
#######################################################################################
#FIX -> FP
# def DtoB(num,datawidth,fracBits):
#     if num >=0:
#         num = num*(2**fracBits) #左移，转化为整型
#         num = int(num) #舍尾
#         e = bin(num)[2:].zfill(datawidth)
#     else:
#         num = -num
#         num = num*(2**fracBits)
#         num = round(num)
#         if num == 0:
#             d = 0
#             e = bin(d)[2:].zfill(datawidth)
#         else :
#             d = 2**datawidth - num
#             e = bin(d)[2:]
#     return e

# #FIX -> FP
# def BtoD(bin_num,datawidth,fracBits):
#     num = int(bin_num,2)
#     if(num)<2**(datawidth-1):
#         d = num*2**-fracBits
#     else:
#         d = (num-2**(datawidth))*2**-fracBits
#     return d

##########################################################################################
##        Serial(UART) API
##########################################################################################
def uart_recv(ser):
    recv_lst = []
    data = ser.read(8)
    print("\033[1;35mRECV\033[0m")
    hex_str = data.hex()
    int_value = int(hex_str,16)
    bin_str = bin(int_value)[2:].zfill(64)
    print(hex_str)
    for i in range(8):
        bin_sub_str = bin_str[8*i:8*i+8]
        #print(bin_sub_str,end=' ')
        item_fix_obj = FixedPoint('0b'+bin_sub_str,
                            signed=True,
                            m=1,
                            n=7,
                            str_base=2,
                            overflow='clamp',
                            overflow_alert='warning')
        result_value = float(item_fix_obj)
        recv_lst.append(result_value)
        #print(result_value)
    print('\033[1;32m',end='')
    print(recv_lst,end='')
    print('\033[0m')
    return recv_lst
    
def uart_send(ser,send_lst):
    hex_str = ''
    num_lst =[]
    for byte_item in send_lst:
        '''
        先发16bit的高字节,再发低字节,little endia
        '''
        ser.write(byte_item[0:1])
        ser.write(byte_item[1:2])

        hex_str += byte_item.hex()
        item_fix_obj = FixedPoint('0x'+byte_item.hex(),
                                  signed=True,
                                  m=9,
                                  n=7,
                                  str_base=2,
                                  overflow='clamp',
                                  overflow_alert='warning')
        num_value = float(item_fix_obj)
        num_lst.append(num_value)


    print("\033[1;35mSEND\033[0m")
    print(hex_str)
    print('\033[1;32m',end='')
    print(num_lst,end='')
    print('\033[0m')

def UART_TandR(MODE='NORMAL',ser_com='COM3',baud_rate=115200,input_array=None):
    #bps = baud_rate  * 0.9  beacuse stop bits dont transmit valid number
    #ser_com = 'COMx' in win  ,sec_com='/dev/ttyUSBx in linux'
    #input array: 96 len numpy array, with element constraint[-256,256)
    send_lst = []
    if(MODE=='NORMAL'):
        input_max = FIXCFG.max_i_value()
        input_min = FIXCFG.min_i_value()
        for num in input_array:
            if(num>=float(input_max)):
                bin_str = str(input_max)
            elif(num<=float(input_min)):
                bin_str = str(input_min)
            else:
                bin_str = str(FixedPoint(   num,
                                        signed=True,
                                        m=FIXCFG.Input_W - FIXCFG.Input_Frac_W,
                                        n=FIXCFG.Input_Frac_W,
                                        str_base=2,
                                        overflow='clamp',
                                        overflow_alert='warning'))
            int_value  = int(bin_str,2)
            byte_value = int_value.to_bytes(2,byteorder="big")
            send_lst.append(byte_value)
    
    ser = serial.Serial(    port=ser_com,
                            baudrate=baud_rate,
                            timeout=1,
                            parity=serial.PARITY_NONE,  # 校验位
                            stopbits=serial.STOPBITS_ONE,  # 停止位
                            bytesize=serial.EIGHTBITS  # 数据位
                            )
    print("="*100)
    uart_send(ser,send_lst)
    recv_lst=uart_recv(ser)
    return recv_lst

if __name__ == "__main__":
    UART_TandR(input_array=[0.5 for _ in range(96)])