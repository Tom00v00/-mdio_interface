# #mdio_interface MDIO接口的收发模块

    这个模块用来实现MDIO协议的收发，适用于MDIO协议通信的芯片。

接口说明：
module mdio_interface (
        input	wire	[0:0]		iclk_100m               ,
        input	wire	[1:0]		i_operation             ,//01：写操作 10：读操作
        input	wire	[4:0]		i_phy_addr              ,//PHY层地址
        input	wire	[4:0]		i_reg_addr              ,//寄存器地址
        input	wire	[15:0]		i_master_write_data     ,//要写入到寄存器的数据
        input	wire	[0:0]		i_operation_begin       ,//一次读写操作开始

        output	reg    	[15:0]      o_master_read_data      ,//从从机的某个寄存器上读取到的数据
        output	reg	    [0:0]		o_master_read_data_valid,
        output	reg	    [0:0]		o_operation_finish      ,//一次读写操作结束
        output	reg	    [0:0]		o_mdio_master_busy      ,//主机占用总线
        output	reg	    [0:0]		o_salve_ack_ready       ,//从机准备好应答
        output	reg	    [0:0]       o_mdc		        ,//5MHz
        inout	wire	[0:0]		o_mdio		
);

实现逻辑：
        输入的PHY层地址，寄存器地址等参数组合成一个长的数字串，然后逐个发送。
        使用状态机控制时序，选择是读或者写流程。
        使用STATE_IDLE初始化各个寄存器的初始值，减少异步复位信号的使用，确保状态都是属于已知的状态。
```

```
