`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: JYLK
// Engineer: WangGaoWen
// 
// Create Date: 2023-11-15 
// Design Name: WangGaowen
// Module Name: 
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Table 12. Management Frame Format 
//                              Management Frame Fields 
//                      Preamble        ST      OP      PHYAD   REGAD   TA      DATA                    IDLE
//              Read    1…1             01      10      AAAAA   RRRRR   Z0      DDDDDDDDDDDDDDDD        Z 
//              Write   1…1             01      01      AAAAA   RRRRR   10      DDDDDDDDDDDDDDDD        Z
//              mdc period >> 80 ns mdc的频率选择为5MHz
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
 
`timescale 1ns/1ns

module mdio_interface (
        input	wire	[0:0]		iclk_100m               ,
        input	wire	[1:0]		i_operation             ,//01：写操作 10：读操作
        input	wire	[4:0]		i_phy_addr              ,//PHY层地址
        input	wire	[4:0]		i_reg_addr              ,//寄存器地址
        //input	wire	[1:0]		i_ta                    ,//
        input	wire	[15:0]		i_master_write_data     ,//要写入到寄存器的数据
        input	wire	[0:0]		i_operation_begin       ,//一次读写操作开始

        output	reg	[15:0]          o_master_read_data      ,//从从机的某个寄存器上读取到的数据
        output	reg	[0:0]		o_master_read_data_valid,
        output	reg	[0:0]		o_operation_finish      ,//一次读写操作结束
        output	reg	[0:0]		o_mdio_master_busy      ,//主机占用总线
        output	reg	[0:0]		o_salve_ack_ready       ,//从机准备好应答
        output	reg	[0:0]           o_mdc		        ,//5MHz
        inout	wire	[0:0]		o_mdio		
);

localparam	PREAMBLE = {32{1'b1}}   ,
                ST       = 2'b01        ;

localparam	STATE_IDLE     = 3'd0 ,
                STATE_WRITE    = 3'd1 ,
                STATE_READ     = 3'd2 ,
                STATE_ACK      = 3'd3 ,
                STATE_ACK_DATA = 3'd4 ,
                STATE_DONE     = 3'd5 ;

localparam	DATA_M_READ_LEN  = 'd46 ,
                DATA_M_WRITE_LEN = 'd64 ;

reg	[2:0]		state   ;

//读写开始信号打拍
reg	[0:0]		r_operation_begin_0 ;
reg	[0:0]		r_operation_begin_1 ;
wire	[0:0]		r_operation_begin_p ;
wire	[0:0]		r_operation_begin_n ;

always @(posedge iclk_100m) begin
        begin
                r_operation_begin_0 <= i_operation_begin ;
                r_operation_begin_1 <= r_operation_begin_0 ;
        end
end

assign r_operation_begin_p = ( r_operation_begin_0) && (~r_operation_begin_1) ;
assign r_operation_begin_n = (~r_operation_begin_0) && ( r_operation_begin_1) ;

//整合前缀信息为一个信息头寄存器
reg	[DATA_M_WRITE_LEN:0]		r_m_wirte_instruction ;   
reg	[DATA_M_READ_LEN:0]		r_m_read_instruction ;

always @(posedge iclk_100m) begin
        if (state == STATE_IDLE) begin
                o_mdio_master_busy <= 1'b0 ;
                r_m_read_instruction <= 47'h0 ;
                r_m_wirte_instruction <= 64'h0 ;
                o_master_read_data_valid <= 1'b0 ;
                o_operation_finish <= 1'b0 ;
        end
        begin
                case (state)
                        STATE_IDLE : begin
                                if (r_operation_begin_p && i_operation == 2'b01) begin
                                        r_m_wirte_instruction <= {PREAMBLE , ST , i_operation , i_phy_addr , i_reg_addr , 2'b10 , i_master_write_data} ;
                                        o_mdio_master_busy <= 1'b1 ;
                                        state <= STATE_WRITE ;
                                end
                                else if (r_operation_begin_p && i_operation == 2'b10) begin
                                        r_m_read_instruction <= {PREAMBLE , ST , i_operation , i_phy_addr , i_reg_addr} ;
                                        o_mdio_master_busy <= 1'b1 ;
                                        state <= STATE_READ ;
                                end
                                else begin
                                        state <= state ;
                                end
                        end 
                        STATE_WRITE : begin
                                if (r_byte_tx_num == DATA_M_WRITE_LEN && time_ctrl_cnt == 5'h09) begin
                                        state <= STATE_DONE ;
                                end
                                else begin
                                        state <= state ;
                                end
                        end
                        STATE_READ : begin 
                                if (r_byte_tx_num == DATA_M_READ_LEN && time_ctrl_cnt == 5'h09) begin
                                        o_mdio_master_busy <= 1'b0 ; 
                                        state <= STATE_ACK ;
                                end
                                else begin
                                        state <= state ;
                                end
                        end 
                        STATE_ACK : begin
                                if (o_salve_ack_ready) begin
                                        state <= STATE_ACK_DATA ;
                                end
                                else if (r_ack_wait_time == 8'd50) begin
                                        $display("应答超时，重新发送消息头");
                                        state <= STATE_READ ;
                                end
                                else if (r_ack_wait_time == 8'd100) begin
                                        $display("应答错误");
                                        state <= STATE_DONE ;
                                end
                                else begin
                                        state <= STATE_ACK ;
                                end
                        end
                        STATE_ACK_DATA : begin
                                if (r_byte_rx_num == 8'd16 && time_ctrl_cnt == 5'd19) begin
                                        o_master_read_data <= r_s_ack_data_in ;
                                        o_master_read_data_valid <= 1'b1 ; 
                                        state <= STATE_DONE ;
                                end
                                else begin
                                        state <= state ;
                                end
                        end
                        STATE_DONE : begin       
                                o_operation_finish <= 1'b1 ;
                                state <=STATE_IDLE ;
                        end
                        default: state <= STATE_IDLE ;
                endcase
        end
end

//分频，源时钟100M，目标时钟5M，相差20倍，计数器最大值为20
reg	[4:0]		time_ctrl_cnt ;

always @(posedge iclk_100m) begin
        if (state == STATE_IDLE) begin
                time_ctrl_cnt <= 5'h0 ;
        end
        else if (time_ctrl_cnt == 5'd19) begin
                time_ctrl_cnt <= 5'h0 ;
        end
        else begin
                time_ctrl_cnt <= time_ctrl_cnt + 1'b1 ;
        end
end

reg	[0:0]		r_mdc_p , r_mdc_n ;

always @(posedge iclk_100m) begin
        if (state == STATE_IDLE) begin
                o_mdc <= 1'b1 ;
                r_mdc_p <= 1'b0 ;
                r_mdc_n <= 1'b0 ;
        end
        else if (time_ctrl_cnt == 5'd09) begin//下降沿
                o_mdc <= 1'b0 ;
                r_mdc_n <= 1'b1 ;
        end
        else if (time_ctrl_cnt == 5'd19) begin//上升沿
                o_mdc <= 1'b1 ;
                r_mdc_p <= 1'b1 ;
        end
        else begin
                o_mdc <= o_mdc ;
                r_mdc_p <= 1'b0 ;
                r_mdc_n <= 1'b0 ;
        end
end

//发送消息头信息,mdc时钟的下降沿更新数据
reg	[0:0]		r_mdio_out      ;
reg	[15:0]		r_s_ack_data_in ;
reg	[7:0]		r_byte_tx_num   ;
reg	[7:0]		r_byte_rx_num   ;


always @(posedge iclk_100m) begin
        if (state == STATE_IDLE) begin
                r_mdio_out <= 1'bz ;
                r_byte_tx_num <= 8'h00 ;
        end
        else if (state == STATE_WRITE && time_ctrl_cnt == 5'd09 && r_byte_tx_num < DATA_M_WRITE_LEN) begin
                r_mdio_out <= r_m_wirte_instruction[DATA_M_WRITE_LEN - r_byte_tx_num - 1] ;
                r_byte_tx_num <= r_byte_tx_num + 1'b1 ;
        end
        else if (state == STATE_READ && time_ctrl_cnt == 5'd09 && r_byte_tx_num < DATA_M_READ_LEN) begin//低位优先接收数据
                r_mdio_out <= r_m_read_instruction[DATA_M_READ_LEN - r_byte_tx_num - 1] ;
                r_byte_tx_num <= r_byte_tx_num + 1'b1 ;
        end
        else begin
                r_mdio_out <= r_mdio_out ;
                r_byte_tx_num <= r_byte_tx_num ;
        end
end
//判断是否应答超时,接收数据，确认从机的应答信号
reg	[7:0]		r_ack_wait_time ;
always @(posedge iclk_100m) begin
        if (state == STATE_IDLE) begin
                r_ack_wait_time <= 8'h0 ;
        end
        else if (state == STATE_ACK) begin
                r_ack_wait_time <= r_ack_wait_time + 1'b1 ;
        end
        else begin
                r_ack_wait_time <= r_ack_wait_time ;
        end
end

always @(posedge iclk_100m) begin
        if (state == STATE_IDLE) begin
                o_salve_ack_ready <= 1'b0 ;
        end
        else if (state == STATE_ACK && time_ctrl_cnt == 5'd19 && r_mdio_in == 1'b0 && r_ack_wait_time < 8'd50) begin
                o_salve_ack_ready <= 1'b1 ;
        end
        else begin
                o_salve_ack_ready <= 1'b0 ;
        end
end

always @(posedge iclk_100m) begin
        if (state == STATE_IDLE) begin
                r_s_ack_data_in <= 16'h0 ;
                r_byte_rx_num <= 8'h0 ;
        end
        else if (state == STATE_ACK_DATA && time_ctrl_cnt == 5'd19 && r_byte_rx_num < 8'd16) begin
                r_s_ack_data_in[r_byte_rx_num] <= r_mdio_in ;
                r_byte_rx_num <= r_byte_rx_num + 1'b1 ;
        end
        else begin
                r_s_ack_data_in <= r_s_ack_data_in ;
                r_byte_rx_num <= r_byte_rx_num ;
        end
end

//三态门
wire	[0:0]		r_mdio_in ;
assign o_mdio = o_mdio_master_busy ? r_mdio_out : 1'bz ;
assign r_mdio_in = o_mdio ;








endmodule