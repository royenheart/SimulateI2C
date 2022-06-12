`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: RoyenHeart、Ruoxuan Wang
//
// Create Date: 2022/06/12 10:36:05
// Design Name:
// Module Name: i2cDriver
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

// @deprecated
module i2cDriver (clk,
                  rst,
                  rw,
                  devAddr,
                  devInnerAddr,
                  sendData,
                  readData,
                  done,
                  scl,
                  sda);
    
    input wire clk;
    input wire rst;
    // 为1的时候表示读，0的时候表示写
    input wire rw;
    input wire [6:0] devAddr;
    input wire [7:0] devInnerAddr;
    input wire [7:0] sendData;
    output wire [7:0] readData;
    output wire done;
    output wire scl;
    inout wire sda;
    
    wire readEnable;
    wire sendEnable;
    wire [1:0] doneBuffer;
    wire [1:0] sclBuffer;
    wire [1:0] sdaBuffer;
    reg  sdaOut;
    wire [1:0] sdaModeExpose;
    
    assign sendEnable = (!rw)?1'b1:1'b0;
    assign readEnable = (rw)?1'b1:1'b0;
    assign done       = (rw)?doneBuffer[1]:doneBuffer[0];
    assign scl        = (rw)?sclBuffer[1]:sclBuffer[0];
    assign sda        = (rw)?((sdaModeExpose[1])?sdaOut:1'dz):((sdaModeExpose[0])?sdaOut:1'dz);
    assign sdaBuffer[1] = sda;
    assign sdaBuffer[0] = sda;
    
    always @(sdaBuffer[1] or sdaBuffer[0]) begin
        if (rw) begin
            sdaOut = sdaBuffer[1];
        end
        else begin
            sdaOut = sdaBuffer[0];
        end
    end

    i2cSend send(
    .clk          (clk),
    .rst          (rst),
    .sendEnable   (sendEnable),
    
    .devAddr      (devAddr),
    .devInnerAddr (devInnerAddr),
    .sendData     (sendData),
    
    .done         (doneBuffer[0]),
    .scl          (sclBuffer[0]),
    .sda          (sdaBuffer[0]),
    .sdaModeExpose(sdaModeExpose[0])
    );
    
    i2cRecv recv(
    .clk          (clk),
    .rst          (rst),
    .RecvEna      (readEnable),
    
    .DeviceAddr   (devAddr),
    .RegisterAddr (devInnerAddr),
    .ReadData     (readData),
    
    .ReadDoneFlag (doneBuffer[1]),
    .scl          (sclBuffer[1]),
    .sda          (sdaBuffer[1]),
    .sdaModeExpose(sdaModeExpose[1])
    );
    
endmodule
