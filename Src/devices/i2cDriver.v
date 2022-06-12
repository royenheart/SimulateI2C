module i2cDriver (
    input clk,
    input rst,
    input rw,

    input devAddr,
    input devInnerAddr,
    input sendData,
    output readData,
    output done,
    
    output scl,
    inout sda);
    
wire clk;
wire rst;
// 为1的时候表示读，0的时候表示写
wire rw;
wire [6:0] devAddr;
wire [7:0] devInnerAddr;
wire [7:0] sendData;
wire [7:0] readData;
wire done;
wire scl;
wire sda;

wire readEnable;
wire sendEnable;
wire [1:0] doneBuffer;
wire [1:0] sclBuffer;
wire [1:0] sdaBuffer;

assign sendEnable = (!rw)?1'b1:1'b0;
assign readEnable = (rw)?1'b1:1'b0;
assign done = (rw)?doneBuffer[1]:doneBuffer[0];
assign scl = (rw)?sclBuffer[1]:sclBuffer[0];
assign sda = (rw)?sdaBuffer[1]:sdaBuffer[0];

i2cSend send(
    .clk          (clk),
    .rst          (rst),
    .sendEnable   (sendEnable),
    
    .devAddr      (devAddr),
    .devInnerAddr (devInnerAddr),
    .sendData     (sendData),

    .done         (doneBuffer[0]),
    .scl          (sclBuffer[0]),
    .sda          (sdaBuffer[0])
);

I2CRecv recv(
    .clk          (clk),
    .rst          (rst),
    .RecvEna      (readEnable),
    
    .DeviceAddr   (devAddr),
    .RegisterAddr (devInnerAddr),
    .ReadData     (readData),

    .ReadDoneFlag (doneBuffer[1]),
    .scl          (sclBuffer[1]),
    .sda          (sdaBuffer[1])
);

endmodule