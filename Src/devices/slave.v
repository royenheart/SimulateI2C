`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 谢皓泽
// 
// Create Date: 2022/06/12 10:36:05
// Design Name: 
// Module Name: slave
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

`define timeslice 72

module slave(scl,
             sda);
    
    //------输入输出类型
    input wire scl;
    inout wire sda;
    //------输入输出类型
    
    reg sdaMode;              //SDA数据输出的控制信号
    
    reg [7:0] memory [255:0];  //数组模拟存储器
    reg [7:0] address;         //地址总线
    reg [7:0] writeBuffer;      //数据输入输出寄存器
    reg [7:0] sdaBuffer;       //SDA数据输出寄存器
    reg [7:0] shift;           //SDA数据输入寄存器
    reg [7:0] devInnerAddr;    //内部存储单元地址寄存器
    reg [7:0] devAddr;         //控制字寄存器（设备地址+控制位）
    reg [1:0] state;           //状态寄存器
    
    //------设备参数和变量
    parameter myDevId = 7'b1000000;
    integer i;
    //------设备参数和变量

    //------sda控制
    assign sda = (sdaMode == 1)?sdaBuffer[7:7]:1'bz;
    //------sda控制
    
    //------------寄存器和存储器初始化---------------
    initial begin
        devInnerAddr = 0;
        devAddr      = 0;
        sdaMode      = 0;
        sdaBuffer    = 0;
        state        = 2'b00;
        writeBuffer  = 0;
        address      = 0;
        shift        = 0;
        $readmemh("../../../../../data/slaveData.txt", memory);
    end
    
    //------启动信号
    always@(negedge sda) begin
        if (scl) begin
            state = state + 1;
            if (state == 2'b11) begin
                disable write;
            end
        end
    end
    //------启动信号
    
    //------从机状态机
    always@(posedge sda) begin
        if (scl) begin
            stopOpt;
        end
        else begin
            casex(state)
                2'b01: begin
                    readData;
                    if (devAddr[7:1] == myDevId) begin
                        state = 2'b10;
                        write;
                    end
                    else begin
                        state = 2'b00;
                    end
                end
                2'b11: begin
                    read;
                end
                default: state = 2'b00;
            endcase
        end
    end
    //------从机状态机
    
    task stopOpt; begin
        state        = 2'b00;
        devInnerAddr = 0;
        devAddr      = 0;
        sdaMode      = 0;
        sdaBuffer    = 0;
    end
    endtask
    
    task readData; begin
        shift_in(devAddr);
        shift_in(devInnerAddr);
    end
    endtask
    
    task write; begin
        shift_in(writeBuffer);
        address         = devInnerAddr;
        memory[address] = writeBuffer;
        state           = 2'b00;
    end
    endtask
    
    task read; begin
        shift_in(devAddr);
        if (devAddr[7:1] == myDevId) begin
            address   = devInnerAddr;
            sdaBuffer = memory[address];
            // 输出
            shift_out;
            state = 2'b00;
        end
    end
    endtask
    
    task shift_in;
        output[7:0] shift;
        begin
            @(posedge scl) shift[7] = sda;
            @(posedge scl) shift[6] = sda;
            @(posedge scl) shift[5] = sda;
            @(posedge scl) shift[4] = sda;
            @(posedge scl) shift[3] = sda;
            @(posedge scl) shift[2] = sda;
            @(posedge scl) shift[1] = sda;
            @(posedge scl) shift[0] = sda;
            @(negedge scl) begin
                #`timeslice;
                sdaMode   = 1;     //应答信号输出
                sdaBuffer = 0;
            end
            @(negedge scl) begin
                #`timeslice;
                sdaMode = 0;
            end
        end
    endtask
    
    task shift_out; begin
        sdaMode = 1;
        for(i = 6; i >= 0; i = i - 1) begin
            // 只有在scl为低电平的时候才进行数据输出
            @(negedge scl) begin
                #`timeslice;
                sdaBuffer = sdaBuffer << 1;
            end
        end
        @(negedge scl) #`timeslice sdaBuffer[7:7] = 1;    //非应答信号输出
        @(negedge scl) #`timeslice sdaMode      = 0;
    end
    endtask
    
endmodule
