`timescale 1ns / 1ps

`include "ctrl_signal_def.v"
module MUX_3to1_LMD(X, Y, Z,Z_, control, out);
    input  [31:0] X;        //临时寄存器ALUOut中的内容
    input  [31:0] Y;        //临时寄存器LMD中的内容
    input  [31:2] Z;        //PC+4
    input  [1:0]  Z_;
    input  [1:0]  control;  //选择控制信号
    output reg [31:0] out;   //输出选择结果

    always @ (X or Y or Z or control) begin
        case(control)
            `WDSel_FromALU  : out = X;  //选择X
            `WDSel_FromMEM  : out = Y;  //选择Y
            `WDSel_FromPC   : out = {Z,Z_};  //选择Z
            `WDSel_Else     : out = 0;
        endcase
    end
endmodule
