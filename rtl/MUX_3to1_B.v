`include "ctrl_signal_def.v"
module MUX_3to1_B(X, Y, Z, control, out,mem_ALU_result,wb_WD,ex_rs2, mem_rd, wb_rd,
                  mem_RFWrite, wb_RFWrite,Y_2,Z_2);
    input  signed [31:0] X;        //临时寄存器B中的内容
    input  signed [31:0] Y,Y_2;        //临时寄存器Imm中的内容
    input         [11:0] Z,Z_2;        //临时寄存器Offset中的内容
    input         [1:0]  control;  //选择控制信号
    output reg signed [31:0] out;   //输出选择结果
    
    input [31:0] mem_ALU_result; // 上一条指令算出的结果 (MEM 阶段前递)
    input [31:0] wb_WD;          // 上上条指令准备写回的结果 (WB 阶段前递)
    input [4:0] ex_rs2, mem_rd, wb_rd;
    input mem_RFWrite, wb_RFWrite;
    
    wire [1:0] ForwardB;
    // 前递优先级：MEM 阶段优先于 WB 阶段 (因为 MEM 更新)
    assign ForwardB = ((mem_RFWrite) && (mem_rd != 5'd0) && (mem_rd == ex_rs2)) ? 2'b10 :
                      ((wb_RFWrite)  && (wb_rd != 5'd0)  && (wb_rd == ex_rs2))  ? 2'b01 : 2'b00;

    wire [31:0] Forwarded_Data;
    assign Forwarded_Data = (ForwardB == 2'b10) ? mem_ALU_result :
                            (ForwardB == 2'b01) ? wb_WD : X;

    always @ (X or Y_2 or Z_2 or control) begin
        case(control)
            `ALUSrcB_B      : out = Forwarded_Data;          //选择X
            `ALUSrcB_Imm    : out = Y_2;          //选择Y
            `ALUSrcB_Offset : out = $signed(Z_2); //选择Z（符号扩展为32位）
            `ALUSrcB_else   : out = Forwarded_Data;          //选择X
        endcase
    end
endmodule