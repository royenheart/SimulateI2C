`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2022/06/12 10:36:05
// Design Name: 王若譞
// Module Name: I2CRecv
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


module I2CRecv(
        clk, rst, RecvEna,
        DeviceAddr, RegisterAddr, 
        ReadData, ReadDoneFlag,
        scl, sda
    );

input clk;                      //时钟信号
input rst;                      //复位信号
input RecvEna;                  //使能信号
input [6:0] DeviceAddr;         //从机物理地址
input [7:0] RegisterAddr;       //从机寄存器地址
output [7:0] ReadData;          //接收数据
output ReadDoneFlag;            //结束标志 
output scl;                     //I2C总线串行时钟线
inout sda;                      //I2C总线双向数据线

reg [7:0] ReadData;
reg ReadDoneFlag;

parameter C_DIV_SELECT = 10'd500;
parameter C_DIV_SELECT0 = (C_DIV_SELECT >> 2) - 1;
parameter C_DIV_SELECT1 = (C_DIV_SELECT >> 1) - 1;
parameter C_DIV_SELECT2 = (C_DIV_SELECT0 >> C_DIV_SELECT1) - 1;
parameter C_DIV_SELECT3 = (C_DIV_SELECT >> 1) + 1;

reg [9:0] sclCnt;               //scl时钟计数器
reg sclEna;                     //scl使能信号
reg [3:0] state;                //状态
reg sdaMode;                    //sda模式，1为输出，0为输入
reg sdaReg;                     //sda寄存器
reg [7:0] LoadData;             //发送过程中加载的数据
reg [3:0] SendCnt;              //发送数据字节数
reg ack;                        //应答
reg [3:0] Jumpstate;            //下一状态
reg [7:0] ReadDataReg;          //读取数据寄存器
wire W_scl_low_mid;             //SCL低电平中间标志位
wire W_scl_high_mid;            //SCL高电平中间标志位
wire W_scl_neg;

assign sda = (sdaMode == 1) ? sdaReg : 1'dz;

always @(posedge clk or negedge rst) begin
    if(!rst) begin
        sclCnt <= 10'b0;
    end
    else if(sclEna)
        begin
            if(sclCnt == C_DIV_SELECT - 1'b0)
                sclCnt <= 10'b0;
            else
                sclCnt <= sclCnt + 1;
        end
        else
            sclCnt <= 10'b0;
end

assign scl = (sclCnt <= C_DIV_SELECT1) ? 1'b1 : 1'b0;
assign W_scl_low_mid = (sclCnt == C_DIV_SELECT2) ? 1'b1 : 1'b0;
assign W_scl_high_mid = (sclCnt == C_DIV_SELECT0) ? 1'b1 : 1'b0;
assign W_scl_neg = (sclCnt == C_DIV_SELECT3) ? 1'b1 : 1'b0;


always @(posedge clk or negedge rst) begin
    if(!rst)
    begin
        sclEna <= 1'b0;
        state <= 4'b0;
        sdaMode <= 1'b1;
        sdaReg <= 1'b1;
        LoadData <= 8'b0;
        SendCnt <= 4'b0;
        ack <= 1'b0;
        Jumpstate <= 4'b0;
        ReadDataReg <= 8'b0;
    end
    else if(RecvEna)
        begin
            case(state)
                4'd0:                   //空闲状态，初始化
                begin
                    sclEna <= 1'b0;
                    state <= 4'd1;
                    sdaMode <= 1'b1;
                    sdaReg <= 1'b1;
                    LoadData <= 8'b0;
                    SendCnt <= 4'b0;
                    ack <= 1'b0;
                    Jumpstate <= 4'd0;
                    ReadDataReg <= 8'b0;                    
                end
                4'd1:                   //加载I2C设备物理地址
                begin
                    state <= 4'd3;
                    Jumpstate <= 4'd4;
                    LoadData <= {DeviceAddr, 1'b0}; 
                end
                4'd2:                   //加载I2C数据地址
                begin
                    state <= 4'd4;
                    Jumpstate <= 4'd7;
                    LoadData <= RegisterAddr;
                end
                4'd3:                   //发送第一个起始信号
                begin
                    sclEna <= 1'b1;
                    sdaMode <= 1'b1;
                    if(W_scl_high_mid)
                    begin
                        sdaReg <= 1'b0;
                        state <= 4'd4;
                    end
                end
                4'd4:                   //发送
                begin
                    sclEna <= 1'b1;
                    sdaMode <= 1'b1;
                    if(W_scl_low_mid)
                    begin
                        if(SendCnt == 4'd8)
                        begin
                            SendCnt <= 4'd0;
                            state <= 4'd5;
                        end
                        else
                        begin
                            sdaReg <= LoadData[7-SendCnt];
                            SendCnt <= SendCnt + 1'b1;
                        end
                    end
                end
                4'd5:                   //接受应答
                begin
                    sclEna <= 1'b1;
                    sdaReg <= 1'b0;
                    sdaMode <= 1'b0;
                    if(W_scl_high_mid)
                    begin
                        ack <= sda;
                        state <= 4'd6;
                    end
                end
                4'd6:                   //检验应答
                begin
                   sclEna <= 1'b1;
                   if(ack == 1'b0)
                   begin
                       if(W_scl_neg == 1'b1)
                       begin
                           state <= Jumpstate;
                           sdaMode <= 1'b1;
                           sdaReg <= 1'b1;
                       end
                   end 
                end
                4'd7:                   //发送第二次起始信号
                begin
                    sclEna <= 1'b1;
                    sdaMode <= 1'b1;
                    if(W_scl_high_mid)
                    begin
                        sdaReg <= 1'b0;
                        state <= 4'd8;
                    end
                end
                4'd8:                   //第二次加载I2C物理地址
                begin
                    state <= 4'd4;
                    Jumpstate <= 4'd9;
                    LoadData <= {DeviceAddr, 1'b1}; 
                end
                4'd9:                   //读数据
                begin
                    sclEna <= 1'b1;
                    sdaMode <= 1'b0;
                    if(W_scl_high_mid)
                    begin
                        if(SendCnt == 4'd7)
                        begin
                            SendCnt <= 4'd0;
                            state <= 4'd10;
                            ReadData <= {ReadDataReg, sda};
                        end
                        else
                        begin
                            ReadDataReg <= {ReadDataReg, sda};
                            SendCnt <= SendCnt + 1'b1;
                        end
                    end
                end
                4'd10:                  //主机发送非应答信号1给从机
                begin
                    sclEna <= 1'b1;
                    sdaMode <= 1'b1;
                    if(W_scl_low_mid)
                    begin
                        state <= 4'd11;
                        sdaReg <= 1'b1;
                    end
                end
                4'd11:                  //从机收到非应答信号1后，初始化sda为0
                begin
                    sclEna <= 1'b1;
                    sdaMode <= 1'b1;
                    if(W_scl_low_mid)
                    begin
                        state <= 4'd12;
                        sdaReg <= 1'b0;
                    end
                end
                4'd12:                  //发送停止信号
                begin
                    sclEna <= 1'b1;
                    sdaMode <= 1'b1;
                    if(W_scl_high_mid)
                    begin
                        sdaReg <= 1'b1;
                        state <= 4'd13;
                    end
                end
                4'd13:                  //结束
                begin
                    sclEna <= 1'b0;
                    sdaMode <= 1'b1;
                    sdaReg <= 1'b1;
                    ReadDoneFlag <= 1'b1;
                    state <= 4'd0;
                    ReadDataReg <= 8'b0;
                end
                default:
                begin
                    state <= 4'd0;
                end
            endcase
        end
        else
        begin
            sclEna <= 1'b0;
            state <= 4'b0;
            sdaMode <= 1'b1;
            sdaReg <= 1'b1;
            LoadData <= 8'b0;
            SendCnt <= 4'b0;
            ack <= 1'b0;
            Jumpstate <= 4'b0;
            ReadDataReg <= 8'b0;
        end
end
endmodule
