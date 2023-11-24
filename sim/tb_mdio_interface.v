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
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
 
`timescale 1ns/1ns

module tb_mdio ();

reg		        iclk_100m	        ;
reg		        sys_rst_n	        ;
reg                     i_operation_begin       ;
reg	[1:0]		operation               ;
wire                    mdio                    ;
wire	[0:0]		mdc                     ;
reg	[15:0]		i_master_write_data     ;
reg	[0:0]		r_mdio                  ;
reg	[46:0]		r_data_read             ;
wire	[0:0]		o_mdio_master_busy      ;
reg	[4:0]		phy_addr                ;
reg	[4:0]		reg_addr                ;
reg	[0:0]		r_ack_busy              ;    

always #5 	iclk_100m = ~iclk_100m 	;

initial begin
        iclk_100m	= 1'b0 ;
        sys_rst_n	= 1'b0 ;
        operation       = 2'b01 ;
        i_operation_begin = 1'b0 ;
        r_ack_busy = 1'b0 ;
        i_master_write_data = 16'hAAAA ;
        phy_addr = 5'b01101 ;        
        reg_addr = 5'b01100 ;
        #100
        sys_rst_n	= 1'b1 ;
        #3000
        i_operation_begin = 1'b1 ;
        #10
        i_operation_begin = 1'b0 ;
        #20_000
        operation = 2'b10 ;
        i_operation_begin = 1'b1 ;
        #10
        i_operation_begin = 1'b0 ;
        
end

assign mdio = r_ack_busy_0 ? r_mdio : 1'bz ;

always @(posedge mdc) begin
        if (o_mdio_master_busy) begin
                r_data_read <= {r_data_read , mdio} ;
        end
        else begin
                r_data_read <= r_data_read ;
        end
end   

always@(negedge mdc) begin 
        if (r_data_read == {32'hffffffff,2'b01,2'b10,phy_addr,reg_addr}) begin
                r_ack_busy <= 1'b1 ;
        end
        else if (r_byte_tx_num > 8'hf) begin
                r_ack_busy <= 1'b0 ;
        end
        else begin
                r_ack_busy <= r_ack_busy ;
        end
end 

reg	[0:0]		r_ack_busy_0 ;
reg	[0:0]		r_ack_busy_1 ;
wire	[0:0]		r_ack_busy_p0;
wire	[0:0]		r_ack_busy_p1;
reg	[7:0]		r_byte_tx_num;

always@(negedge mdc) begin
        r_ack_busy_0 <= r_ack_busy ;
        r_ack_busy_1 <= r_ack_busy_0 ;
end

assign r_ack_busy_p0 = (r_ack_busy) && (~r_ack_busy_0) ;
assign r_ack_busy_p1 = (r_ack_busy_0) && (~r_ack_busy_1) ;

always@(negedge mdc) begin
        if (r_ack_busy_p0) begin
                r_mdio <= 1'b0 ;
                r_byte_tx_num <= 8'h0 ;
        end
        else if (r_ack_busy_0 && r_byte_tx_num <= 8'hf) begin
                r_mdio <= i_master_write_data[r_byte_tx_num] ;
                r_byte_tx_num <= r_byte_tx_num + 1'b1 ;
        end
        else begin
                r_mdio <= r_mdio ;
                r_byte_tx_num <= r_byte_tx_num ;
        end
end

mdio_interface  mdio_interface_master 
(
        .iclk_100m              (iclk_100m),
        //.sys_rst_n               (sys_rst_n),
        .i_operation             (operation),
        .i_phy_addr              (phy_addr),
        .i_reg_addr              (reg_addr),
        .i_master_write_data     (i_master_write_data),
        .i_operation_begin       (i_operation_begin),

        .o_master_read_data      (),
        .o_master_read_data_valid(),
        .o_operation_finish      (),
        .o_mdio_master_busy      (o_mdio_master_busy),
        .o_mdc		         (mdc),//5MHz
        .o_mdio		         (mdio)
);




endmodule

