// 用于临时存储指令的二进制形式
`include "ctrl_signal_def.v"
module IR(in_ins, clk, IRWrite, out_ins);
    input         clk, IRWrite;  //IR寄存器写使能信号
    input  [31:0] in_ins;        //指令输入
    output reg [31:0] out_ins;   //指令输出

    always @(posedge clk) begin  //时钟信号上升沿
        if (IRWrite) begin
            out_ins <= in_ins;    //输出指令
        end
    end
endmodule