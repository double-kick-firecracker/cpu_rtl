`include "ctrl_signal_def.v"
module MUX_2to1_A(X, Y, control, out,mem_ALU_result,wb_WD,ex_rs1, mem_rd, wb_rd,
                  mem_RFWrite, wb_RFWrite);
    input  [31:0] X;        //临时寄存器A中的内容
    input  [4:0]  Y;        //预留输入
    input         control;  //选择控制信号
    output [31:0] out;      //输出选择结果
    input [31:0] mem_ALU_result; // 上一条指令算出的结果 (MEM 阶段前递)
    input [31:0] wb_WD;          // 上上条指令准备写回的结果 (WB 阶段前递)
    input [4:0] ex_rs1, mem_rd, wb_rd;
    input mem_RFWrite, wb_RFWrite;

    wire [1:0] ForwardA;
    // 前递优先级：MEM 阶段优先于 WB 阶段 (因为 MEM 更新)
    assign ForwardA = ((mem_RFWrite) && (mem_rd != 5'd0) && (mem_rd == ex_rs1)) ? 2'b10 :
                      ((wb_RFWrite)  && (wb_rd != 5'd0)  && (wb_rd == ex_rs1))  ? 2'b01 : 2'b00;

    wire [31:0] Forwarded_Data;
    assign Forwarded_Data = (ForwardA == 2'b10) ? mem_ALU_result :
                            (ForwardA == 2'b01) ? wb_WD : X;
    
    assign out = (control == 1'b0 ? Forwarded_Data : {27'b0, Y[4:0]});
endmodule