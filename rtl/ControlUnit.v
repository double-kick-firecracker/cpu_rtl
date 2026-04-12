`timescale 1ns / 1ps

`include "ctrl_signal_def.v"
`include "instruction_def.v"

module ControlUnit(
    input rst,          //
    input clk,          //
    input zero,         //感觉上面三个都用不到？——确实可以退休了
    input [6:0] opcode, //
    input [6:0] Funct7, //
    input [2:0] Funct3, //
    output reg PCWrite, //是否更新PC
    output reg InsMemRW,//是否取指令
    output reg IRWrite, //IR是否输出指令
    output reg RFWrite, //RF是否写入数据
    output reg DMCtrl,  //DM读或写
    output reg ExtSel,  //扩展模式0/signed
    output reg ALUSrcA, //ALUA的来源
    output reg [1:0] ALUSrcB,//ALUB 的来源
    output reg [1:0] RegSel, //写回RF的地址选择
    output reg [1:0] NPCOp,  //NPC的数值来源
    output reg [1:0] WDSel,  //写回data的来源
    output reg [3:0] ALUOp,   //ALU计算模式   
    output reg Jump,
    output reg Branch
);

 reg [1:0] ALU_category ; //对ALU计算模式的细分
    
    always @(*) begin
        PCWrite  = 1'b1;           
        InsMemRW = 1'b1; 
        IRWrite  = 1'b1;    //上面都正常无气泡情况下默认正常输出运行
        RFWrite  = 1'b0;    //默认不写
        DMCtrl   = `DMCtrl_RD;     // 默认不写
        ALUSrcA  = `ALUSrcA_A;     // 默认rs1
        ALUSrcB  = `ALUSrcB_B;     // 默认rs2
        RegSel   = `RegSel_rd;     // 默认写回来源于rd
        WDSel    = `WDSel_FromALU; // 默认写回数据来自ALU
        NPCOp    = `NPC_PC;        // 默认+4
        ExtSel   = `ExtSel_SIGNED;   // 默认有符号拓展
        ALU_category = 2'b00;      // 默认用加法
        Jump     = 1'b0;
        Branch   = 1'b0;
        case (opcode)
            `INSTR_RTYPE_OP: begin
                RFWrite      = 1'b1;
                ALU_category = 2'b10; //即R型
            end
            `INSTR_ITYPE_OP: begin
                RFWrite      = 1'b1;
                ALUSrcB      = `ALUSrcB_Imm;
                ALU_category = 2'b11;        // 即I型，R&I要二次分类
            end
            `INSTR_LW_OP: begin
                RFWrite      = 1'b1;
                ALUSrcB      = `ALUSrcB_Imm; 
                WDSel        = `WDSel_FromMEM; 
                ALU_category = 2'b00;
            end
            `INSTR_SW_OP: begin
                DMCtrl       = `DMCtrl_WR;  
                ALUSrcB      = `ALUSrcB_Offset; 
                ALU_category = 2'b00;   
            end
            `INSTR_BTYPE_OP: begin
                ALU_category = 2'b01;
                NPCOp    = `NPC_Offset12;
                Branch   = 1'b1;
            end
            `INSTR_JAL_OP: begin
                RFWrite      = 1'b1;
                WDSel        = `WDSel_FromPC;  // 将 PC+4 写入 rd
                NPCOp        = `NPC_Offset20;  // 触发 JAL 跳转
                Jump         = 1'b1;
            end
            `INSTR_JALR_OP: begin
                RFWrite      = 1'b1;
                WDSel        = `WDSel_FromPC;  // 将 PC+4 写入 rd
                NPCOp        = `NPC_rs;        // 触发 JALR 跳转，且imm有符号
                ALUSrcB      = `ALUSrcB_Imm;
                Jump         = 1'b1;
            end
            default: ;
        endcase
end
always @(*) begin
    ALUOp = `ALUOp_ADD; 
    case (ALU_category)
        2'b00: ALUOp = `ALUOp_ADD; // Load/Store 算地址，统统用加法
        2'b01: ALUOp = `ALUOp_SUB; // 分支指令，统统用减法去比较
        2'b10: begin // 处理 R 型算术/逻辑指令
            case (Funct3)
                3'b000: ALUOp = (Funct7[5]) ? `ALUOp_SUB : `ALUOp_ADD; // add, sub
                3'b001: ALUOp = `ALUOp_SLL;                            // sll
                3'b100: ALUOp = `ALUOp_XOR;                            // xor
                3'b101: ALUOp = (Funct7[5]) ? `ALUOp_SRA : `ALUOp_SRL; // sra, srl
                3'b110: ALUOp = `ALUOp_OR;                             // or
                3'b111: ALUOp = `ALUOp_AND;                            // and
                default: ALUOp = `ALUOp_ADD;
            endcase
        end
        2'b11: begin 
            case (Funct3)
                `INSTR_ADDI_FUNCT: ALUOp = `ALUOp_ADD; // addi
                `INSTR_ORI_FUNCT:  ALUOp = `ALUOp_OR;  // ori
                default: ALUOp = `ALUOp_ADD;
            endcase
        end
    endcase
end

endmodule
