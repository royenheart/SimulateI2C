`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: 王若譞
//
// Create Date: 2022/06/12 10:36:05
// Design Name:
// Module Name: master
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


module master(clk,
              rst,
              devAddr,
              devInnerAddr,
              sendData,
              readData,
              rw,
              done);
    
    input clk;
    input rst;
    input rw;
    input [6:0] devAddr;
    input [7:0] devInnerAddr;
    input [7:0] sendData;
    output [7:0] readData;
    output done;
    
    wire clk;
    wire rst;
    wire rw;
    wire [6:0] devAddr;
    wire [7:0] devInnerAddr;
    wire [7:0] sendData;
    wire [7:0] readData;
    wire done;
    wire scl;
    wire sda;
    
    i2c u_i2c(
    .clk            (clk),
    .rst            (rst),
    .sendEnable     (!rw),
    .RecvEna        (rw),
    
    .devAddr        (devAddr),
    .devInnerAddr   (devInnerAddr),
    .sendData       (sendData),
    .readData       (readData),
    .done           (done),
    
    .scl            (scl),
    .sda            (sda)
    );

    slave u_slaver(
    .scl    (scl),
    .sda    (sda)
    );
    
endmodule
