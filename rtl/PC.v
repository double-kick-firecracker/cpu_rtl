`timescale 1ns / 1ps

`include "ctrl_signal_def.v"
module PC(clk, rst, PCWrite,StallF, NPC, PC,FlushD,StallD,id_PC,FlushE);
    input         clk,FlushD,StallD,FlushE;        //时钟信号
    input         rst;        //复位信号
    input         PCWrite;    //PC写使能信号
    input  [31:0] NPC;        //下条指令的地址
    input         StallF;
    output reg [31:0] PC;      //本条指令地址,PC本身可以看作IF_PC
    output [31:0] id_PC;    //PC在ID阶段用不到，EXE才需要
    
    always @(posedge clk or posedge rst) begin
        // reset
        if (rst) begin
            PC <= 32'h0000_2000;  //复位后PC的值
        end
        else if (StallF)
            PC <= PC;
        else if (PCWrite) begin
            PC <= NPC;            //修改指令地址
        end
    end
    
    Flopr U_IF_ID_PC (.clk(clk), .rst(rst), .in_data(PC), .out_data(id_PC), .CLR(FlushD), .Stall(StallD) ); 
    
endmodule
