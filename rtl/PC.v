`timescale 1ns / 1ps

`include "ctrl_signal_def.v"
module PC(clk, rst, PCWrite,stall, NPC, PC);
    input         clk;        //时钟信号
    input         rst;        //复位信号
    input         PCWrite;    //PC写使能信号
    input  [31:0] NPC;        //下条指令的地址
    input         stall;
    output reg [31:0] PC;      //本条指令地址

    always @(posedge clk or posedge rst) begin
        // reset
        if (rst) begin
            PC <= 32'h0000_2000;  //复位后PC的值
        end
        else if (stall)
            PC <= PC;
        else if (PCWrite) begin
            PC <= NPC;            //修改指令地址
        end
    end
endmodule
