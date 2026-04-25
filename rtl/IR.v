// 用于临时存储指令的二进制形式
`include "ctrl_signal_def.v"
module IR(in_ins, clk, IRWrite, out_ins, flush,stall,rst);   //该模块当作IF/ID的pipeline reg使用--但感觉不行？
    input         clk, IRWrite,rst;  //IR寄存器写使能信号-->把IRWrite改成气泡控制器
    input  [31:0] in_ins;        //指令输入
    input        flush,stall;
    output reg [31:0] out_ins;   //指令输出
    
    reg flushD,stallD;
    
    always @(posedge clk or posedge rst) begin
        if(rst)begin
         flushD <= 1;
         stallD <= 0;
       end
       else begin
         flushD <= flush;
         stallD <= stall; 
         end
     end
    
    always @(*)begin
        if(flushD)
            out_ins=32'h0000_0013;
        else if(stallD)
            out_ins=out_ins;
        else
            out_ins=in_ins;
    end
    
endmodule
