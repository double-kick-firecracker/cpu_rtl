`timescale 1ns / 1ps
`include "ctrl_signal_def.v"
module IM(InsMemRW, addr, Ins,clk);
    input         InsMemRW;    //指令存储单元信号
    input  [11:2] addr;        //指令存储器地址
    input         clk;
    output reg [31:0] Ins;     //取得的指令
    reg [31:0] memory[0:1023];

    always @(posedge clk) begin
            Ins <= memory[addr];  //根据地址取指令
    end
endmodule
