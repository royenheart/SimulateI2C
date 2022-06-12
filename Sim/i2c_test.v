`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Ruoxuan Wang、RoyenHeart
// 
// Create Date: 2022/06/12 10:36:05
// Design Name: 
// Module Name: i2c_test
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

module i2c_test;

reg clk;
reg rst;
reg rw;
reg [6:0] devAddr;
reg [7:0] devInnerAddr;
reg [7:0] sendData;
wire [7:0] readData;
wire done;

master u_master(
    .clk            (clk),
    .rst            (rst),
    .rw             (rw),

    .devAddr        (devAddr),
    .devInnerAddr   (devInnerAddr),
    .sendData       (sendData),
    .readData       (readData),
    .done           (done)
);

initial begin
    rst = 1'b1;
    clk = 1'b0;
    forever #5 clk = ~clk;
end

// initial begin
//     #10
//         rw = 1'b0;
//         devAddr = 7'b1000000;
//         devInnerAddr = 8'd1;
//         sendData = 8'b10111010; 
// end

initial begin
    #10
        rw = 1'b1;
        devAddr = 7'b1000000;
        devInnerAddr = 8'b00000001;
end

endmodule
