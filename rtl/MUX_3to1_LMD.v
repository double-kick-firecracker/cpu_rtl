`timescale 1ns / 1ps

`include "ctrl_signal_def.v"
module MUX_3to1_LMD(X, Y, Z, control, out,clk,rst);
    input  [31:0] X;        //临时寄存器ALUOut中的内容
    input  [31:0] Y;        //临时寄存器LMD中的内容
    input  [31:0] Z;        //PC+4
    input  [1:0]  control;  //选择控制信号
    output reg [31:0] out;   //输出选择结果
    wire [31:0] X_WB;
    input clk,rst;
    Flopr U_MEM_WB_X  ( .clk(clk), .rst(rst), .in_data(X), .out_data(X_WB),.CLR(1'b0), .Stall(1'b0) );

    always @ (X_WB or Y or Z or control) begin
        case(control)
            `WDSel_FromALU  : out = X_WB;  //选择X
            `WDSel_FromMEM  : out = Y;  //选择Y
            `WDSel_FromPC   : out = Z;  //选择Z
            `WDSel_Else     : out = 0;
            default         : out = 0;
        endcase
    end
endmodule