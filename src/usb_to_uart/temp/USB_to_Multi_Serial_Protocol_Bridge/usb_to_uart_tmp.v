//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.11.02
//Part Number: GW2A-LV18PG256C8/I7
//Device: GW2A-18
//Device Version: C
//Created Time: Mon Jun  9 21:58:11 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	usb_to_uart your_instance_name(
		.phy_clk(phy_clk), //input phy_clk
		.rst_n(rst_n), //input rst_n
		.UART_TXD(UART_TXD), //output UART_TXD
		.UART_RXD(UART_RXD), //input UART_RXD
		.UART_RTS(UART_RTS), //output UART_RTS
		.UART_CTS(UART_CTS), //input UART_CTS
		.BAUD_RATE(BAUD_RATE), //input [31:0] BAUD_RATE
		.PARITY_BIT(PARITY_BIT), //input [7:0] PARITY_BIT
		.STOP_BIT(STOP_BIT), //input [7:0] STOP_BIT
		.DATA_BITS(DATA_BITS), //input [7:0] DATA_BITS
		.TX_DATA(TX_DATA), //input [15:0] TX_DATA
		.TX_DATA_VAL(TX_DATA_VAL), //input TX_DATA_VAL
		.TX_BUSY(TX_BUSY), //output TX_BUSY
		.RX_DATA(RX_DATA), //output [15:0] RX_DATA
		.RX_DATA_VAL(RX_DATA_VAL), //output RX_DATA_VAL
		.status_o(status_o) //output status_o
	);

//--------Copy end-------------------
