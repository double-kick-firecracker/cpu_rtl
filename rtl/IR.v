// 用于临时存储指令的二进制形式
`include "ctrl_signal_def.v"
module IR(in_ins, clk, IRWrite, out_ins, flush,stall,rst);   //该模块当作IF/ID的pipeline reg使用--但感觉不行？
    input         clk, IRWrite,rst;  //IR寄存器写使能信号-->把IRWrite改成气泡控制器
    input  [31:0] in_ins;        //指令输入
    input        flush,stall;
    output reg [31:0] out_ins;   //指令输出
    
    reg flushD,stallD;
    reg [31:0] hold_ins;
    
    always @(posedge clk or posedge rst) begin
        if(rst)begin
         flushD <= 1;
         stallD <= 0;
         hold_ins<=32'h0000_0013;
       end
       else begin
         flushD <= flush;
         stallD <= stall; 
         if (!stallD) begin
                hold_ins <= in_ins;
            end
         end
     end
    
    always @(*)begin
        if(flushD)
            out_ins=32'h0000_0013;
        else if(stallD)
            out_ins=hold_ins;//防止产生latch
        else
            out_ins=in_ins;
    end
    
endmodule
