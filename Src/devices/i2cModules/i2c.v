`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 谢皓泽
// 
// Create Date: 2022/06/12 10:36:05
// Design Name: 
// Module Name: I2CSend
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

`include "./i2cSendHeaders.vh"
`include "./i2cRecvHeaders.vh"

// 主机向从机写数据
module i2c (
    clk,
    rst,
    sendEnable,
    RecvEna,

    devAddr,
    devInnerAddr,
    sendData,
    readData,

    done,
    
    scl,
    sda);
    
//------规定输入输出类型
input wire clk;
input wire rst;
input wire sendEnable;
input wire RecvEna;
input wire [6:0] devAddr;
input wire [7:0] devInnerAddr;
input wire [7:0] sendData;
output wire [7:0] readData;
output reg done;
output wire scl;
inout wire sda;
//------规定输入输出类型

//------模块内变量定义
reg [9:0] countScl; // SCL时钟线计数器
reg       sclEnable; // SCL时钟线使能信号
reg [3:0] state; // 发送模块状态
reg [3:0] jmpState; // 跳转时需要跳转的状态
reg       sdaMode; // sda模式，1输出，0输入
reg       sdaBuffer; // sda缓冲
reg [7:0] ReadDataReg;
reg [7:0] dataBuffer; // 完整8Bits数据缓冲
reg [3:0] hasSendDataBits; // 已发送比特数计数
reg       ack;

wire      sclInLow; // scl处于低电平位
wire      sclInHigh; // scl处于高电平位
wire      sclInNegEdge; // scl处于下降沿  
//------模块内变量定义

//------scl信号标志位产生
parameter sclDiffMiddle = 10'd24;
parameter sclDiff0 = (sclDiffMiddle >> 2) - 1;
parameter sclDiff1 = (sclDiffMiddle >> 1) - 1;
parameter sclDiff2 = (sclDiff0 + sclDiff1) + 1;
parameter sclDiff3 = (sclDiffMiddle >> 1) + 1;

always @(posedge clk or negedge rst) begin
    if (!rst) begin
        countScl <= 10'd0;
    end
    else if (sclEnable) begin
        if (countScl == sclDiffMiddle - 1'b1) begin
            countScl <= 10'd0;
        end
        else begin
            countScl <= countScl + 1'b1;
        end
    end
    else begin
        countScl <= 10'd0;
    end
end

assign scl = (countScl <= sclDiff1)?1'b1:1'b0;
assign sclInLow = (countScl == sclDiff2)?1'b1:1'b0;
assign sclInHigh = (countScl == sclDiff0)?1'b1:1'b0;
assign sclInNegEdge = (countScl == sclDiff3)?1'b1:1'b0;
//------scl信号标志位产生

//------sda信号（从sda缓冲读入）
/// sdaMode为1表示输出模式，将sda缓冲数据写出，为0表示输入模式，设成高阻态，由外部输入决定
assign sda = (sdaMode == 1'b1)?sdaBuffer:1'bz;
//------sda信号（从sda缓冲读入）

//------输出
assign readData = {ReadDataReg, sda};
//------输出

//------状态机实现i2cSend
always @(posedge clk or negedge rst) begin
    if (!rst) begin
        rstParams;
    end
    else if (sendEnable) begin
        case (state)
            `idle: begin
                idleParams;
            end
            `loadDevAddr: begin
                dataBuffer <= {devAddr, 1'b0};
                state <= `sendStart;
                jmpState <= `loadDevInnerAddr;
            end
            `loadDevInnerAddr: begin
                dataBuffer <= devInnerAddr;
                state <= `sendByte;
                jmpState <= `loadSendData;
            end
            `loadSendData: begin
                dataBuffer <= sendData;
                state <= `sendByte;
                jmpState <= `sendStop;
            end
            `sendStart: begin
                sclEnable <= 1'b1;
                sdaMode <= 1'b1;
                if (sclInHigh) begin
                    sdaBuffer <= 1'b0;
                    state <= `sendByte;
                end
                else begin
                    state <= `sendStart;
                end
            end
            `sendByte: begin
                sclEnable <= 1'b1;
                sdaMode <= 1'b1;
                if (sclInLow) begin
                    if (hasSendDataBits == 4'd8) begin
                        // 8Bits传输完成
                        hasSendDataBits <= 4'd0;
                        state <= `recvAck;
                    end
                    else begin
                        sdaBuffer <= dataBuffer[7 - hasSendDataBits];
                        hasSendDataBits <= hasSendDataBits + 1'b1;
                    end
                end
                else begin
                    state <= `sendByte;
                end
            end
            `recvAck: begin
                sclEnable <= 1'b1;
                sdaMode <= 1'b0;
                if (sclInHigh) begin
                    // 接收上位机（主机）应答
                    ack <= sda;
                    state <= `verifyAck;
                end
                else begin
                    state <= `recvAck;
                end
            end
            `verifyAck: begin
                sclEnable <= 1'b1;
                // ack为0表示应答通过
                if (ack == 1'b0) begin
                    if (sclInNegEdge) begin
                        state <= jmpState;
                        sdaMode <= 1'b1;
                        sdaBuffer <= 1'b0;
                    end
                    else begin
                        state <= `verifyAck;
                    end
                end
                else begin
                    state <= `idle;
                end
            end
            `sendStop: begin
                sclEnable <= 1'b1;
                sdaMode <= 1'b1;
                if (sclInHigh) begin
                    sdaBuffer <= 1'b1;
                    state <= `idle;
                end
            end
            `over: begin
                overParams;
            end
            default: state <= `idle;
        endcase
    end
    else if (RecvEna)
        begin
            case(state)
                `ridle:                   //空闲状态，初始化
                begin
                    sclEnable      <= 1'b0;
                    state       <= 4'd1;
                    sdaMode     <= 1'b1;
                    sdaBuffer      <= 1'b1;
                    dataBuffer    <= 8'b0;
                    hasSendDataBits     <= 4'b0;
                    ack         <= 1'b0;
                    jmpState   <= 4'd0;
                    ReadDataReg <= 8'b0;
                end
                `rloadDeviceAddrFirst :                   //加载I2C设备物理地址
                begin
                    state     <= 4'd3;
                    jmpState <= 4'd2;
                    dataBuffer  <= {devAddr, 1'b0};
                end
                `rloadRegisterAddr:                   //加载I2C数据地址
                begin
                    state     <= 4'd4;
                    jmpState <= 4'd7;
                    dataBuffer  <= devInnerAddr;
                end
                `rsendStartFirst:                   //发送第一个起始信号
                begin
                    sclEnable  <= 1'b1;
                    sdaMode <= 1'b1;
                    if (sclInHigh)
                    begin
                        sdaBuffer <= 1'b0;
                        state  <= 4'd4;
                    end
                end
                `rsendByte:                   //发送
                begin
                    sclEnable  <= 1'b1;
                    sdaMode <= 1'b1;
                    if (sclInLow)
                    begin
                        if (hasSendDataBits == 4'd8)
                        begin
                            hasSendDataBits <= 4'd0;
                            state   <= 4'd5;
                        end
                        else
                        begin
                            sdaBuffer  <= dataBuffer[7-hasSendDataBits];
                            hasSendDataBits <= hasSendDataBits + 1'b1;
                        end
                    end
                end
                `rrecvAck:                   //接受应答
                begin
                    sclEnable  <= 1'b1;
                    sdaBuffer  <= 1'b0;
                    sdaMode <= 1'b0;
                    if (sclInHigh)
                    begin
                        ack   <= sda;
                        state <= 4'd6;
                    end
                end
                `rcheckAck:                   //检验应答
                begin
                    sclEnable <= 1'b1;
                    if (ack == 1'b0)
                    begin
                        if (sclInNegEdge == 1'b1)
                        begin
                            state   <= jmpState;
                            sdaMode <= 1'b1;
                            sdaBuffer  <= 1'b1;
                        end
                    end
                end
                `rsendStartSecond:                   //发送第二次起始信号
                begin
                    sclEnable  <= 1'b1;
                    sdaMode <= 1'b1;
                    if (sclInHigh)
                    begin
                        sdaBuffer <= 1'b0;
                        state  <= 4'd8;
                    end
                end
                `rloadDeviceAddrSecond :                   //第二次加载I2C物理地址
                begin
                    state     <= 4'd4;
                    jmpState <= 4'd9;
                    dataBuffer  <= {devAddr, 1'b1};
                end
                `rreadData :                   //读数据
                begin
                    sclEnable  <= 1'b1;
                    sdaMode <= 1'b0;
                    if (sclInHigh)
                    begin
                        if (hasSendDataBits == 4'd7)
                        begin
                            hasSendDataBits  <= 4'd0;
                            state    <= 4'd10;
                        end
                        else
                        begin
                            ReadDataReg <= {ReadDataReg, sda};
                            hasSendDataBits     <= hasSendDataBits + 1'b1;
                        end
                    end
                end
                `rrecvNotAck :                  //主机发送非应答信号1给从机
                begin
                    sclEnable  <= 1'b1;
                    sdaMode <= 1'b0;
                    if (sclInLow)
                    begin
                        state  <= 4'd12;
                        sdaBuffer <= 1'b1;
                    end
                end
                // `rclearSDA :                  //从机收到非应答信号1后，初始化sda为0
                // begin
                //     sclEnable  <= 1'b1;
                //     sdaMode <= 1'b1;
                //     if (sclInLow)
                //     begin
                //         state  <= 4'd12;
                //         sdaBuffer <= 1'b0;
                //     end
                // end
                `rsendStop :                  //发送停止信号
                begin
                    sclEnable  <= 1'b1;
                    sdaMode <= 1'b1;
                    if (sclInHigh)
                    begin
                        sdaBuffer <= 1'b1;
                        state  <= 4'd13;
                    end
                end
                `rover :                  //结束
                begin
                    sclEnable       <= 1'b0;
                    sdaMode      <= 1'b1;
                    sdaBuffer       <= 1'b1;
                    done <= 1'b1;
                    state        <= 4'd0;
                    ReadDataReg  <= 8'b0;
                end
                default:
                begin
                    state <= 4'd0;
                end
            endcase
        end
    else begin
        rstParams;
    end
end 

task rstParams; begin
    state <= `idle;
    jmpState <= `idle;
    sdaMode <= 1'b1;
    sdaBuffer <= 1'b1;
    hasSendDataBits <= 4'd0;
    ReadDataReg <= 8'b0;
    done <= 1'b0;
    ack <= 1'b0;
end
endtask

task idleParams; begin
    state <= `loadDevAddr;
    jmpState <= `idle;
    sdaMode <= 1'b1;
    sdaBuffer <= 1'b1;
    sclEnable <= 1'b0;
    hasSendDataBits <= 4'd0;
    done <= 1'b0;
end
endtask

task overParams; begin
    state <= `idle;
    sdaMode <= 1'b1;
    sdaBuffer <= 1'b1;
    sclEnable <= 1'b0;
    done <= 1'b1;
    ack <= 1'b0;
end
endtask
//------状态机实现i2cSend

endmodule