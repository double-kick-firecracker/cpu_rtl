`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 2024/10/26 09:28:20
// Design Name:
// Module Name: IM
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

`include "ctrl_signal_def.v"
module IM(InsMemRW, addr, Ins);
    input         InsMemRW;    //指令存储单元信号
    input  [11:2] addr;        //指令存储器地址
    output reg [31:0] Ins;     //取得的指令
    reg [31:0] memory[0:1023];

    always @(addr or InsMemRW) begin
        if (InsMemRW) begin
            Ins <= memory[addr];  //根据地址取指令
        end
    end
endmodule