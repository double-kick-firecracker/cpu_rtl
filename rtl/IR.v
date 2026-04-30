// 用于临时存储指令的二进制形式
`include "ctrl_signal_def.v"
module IR(in_ins, clk, IRWrite, out_ins, flush,stall,rst);   //该模块当作IF/ID的pipeline reg使用--但感觉不行？
    input         clk, IRWrite,rst;  //IR寄存器写使能信号-->把IRWrite改成气泡控制器
    input  [31:0] in_ins;        //指令输入
    input        flush,stall;
    output reg [31:0] out_ins;   //指令输出
    reg first_edge_mask;
    always @(posedge clk or posedge rst) begin
    if (rst) begin
        out_ins <= 32'h00000013; 
        first_edge_mask <= 1'b1;  // 标记复位结束
    end else begin
        if (first_edge_mask) begin
            out_ins <= 32'h00000013; 
            first_edge_mask <= 1'b0;
        end else if(flush)
            out_ins <= 32'h00000013;
        else if (!stall)
            out_ins <= in_ins;
    end
end
    
endmodule
