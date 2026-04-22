// 用于临时存储指令的二进制形式
`include "ctrl_signal_def.v"
module IR(in_ins, clk, IRWrite, out_ins, flush,rst,stall);   //该模块当作IF/ID的pipeline reg使用--但感觉不行？
    input         clk, IRWrite,rst;  //IR寄存器写使能信号-->把IRWrite改成气泡控制器
    input  [31:0] in_ins;        //指令输入
    input         flush,stall;
    output reg [31:0] out_ins;   //指令输出
    
    reg [31:0] hold_ins;
    reg        holding;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            holding  <= 1'b0;
            hold_ins <= 32'h0000_0013;     
        end else if (flush) begin
            holding  <= 1'b0;              
        end else if (stall && !holding) begin
            hold_ins <= in_ins;            
            holding  <= 1'b1;              
        end else if (!stall) begin
            holding  <= 1'b0;             
        end
    end

    always @(*)begin
    out_ins = flush   ? 32'h0000_0013 : 
              holding ? hold_ins      :
                        in_ins;
    end
endmodule
