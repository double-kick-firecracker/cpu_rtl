// 用于临时存储指令的二进制形式
`include "ctrl_signal_def.v"
module IR(in_ins, clk, IRWrite, out_ins, flush);   //该模块当作IF/ID的pipeline reg使用——但感觉不行？
    input         clk, IRWrite;  //IR寄存器写使能信号——>把IRWrite改成气泡控制器
    input  [31:0] in_ins;        //指令输入
    input         flush;
    output reg [31:0] out_ins;   //指令输出
    
    always @(*)begin
        out_ins = flush ? 32'h0000_0013 : in_ins;
    end
    
endmodule
