`timescale 1ns / 1ps
`include "ctrl_signal_def.v"
module DM( Addr, WD, clk, DMCtrl, RD, WD2);
    input  [11:2] Addr;      //读写对应的地址
    input  [31:0] WD,WD2;        //写入的数据
    input         clk;       //时钟信号
    input         DMCtrl;    //读写控制信号
    output reg [31:0] RD;    //读出的数据

    reg [31:0] memory[0:1023];
    always @(posedge clk) begin  //信号上升沿
        if (DMCtrl) begin
            memory[Addr] <= WD2;   //写入数据
        end
        else begin
            RD <= memory[Addr];  //读出数据
        end
    end // end always
endmodule