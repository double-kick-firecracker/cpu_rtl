`timescale 1ns / 1ps

`include "ctrl_signal_def.v"
`include "instruction_def.v"

module ControlUnit(
    input rst,          //给流水线寄存器用的
    input clk,          //
    input zero,         //
    input [6:0] opcode, //
    input [6:0] Funct7, //
    input [2:0] Funct3, //
    input [4:0] id_rs1, id_rs2, id_rd,
    input ID_Branch_Taken,        // 来自 NPC 的分支判定结果
    
    output reg PCWrite, //是否更新PC
    output reg InsMemRW,//是否取指令
    output reg IRWrite, //IR是否输出指令
    output reg RFWrite,mem_RFWrite, //RF是否写入数据
    output reg DMCtrl,  //DM读或写
    output reg ExtSel,  //扩展模式0/signed
    output reg ALUSrcA, //ALUA的来源
    output reg [1:0] ALUSrcB,//ALUB 的来源
    output reg [1:0] RegSel, //写回RF的地址选择
    output reg [1:0] NPCOp,  //NPC的数值来源
    output reg [1:0] WDSel,  //写回data的来源
    output reg [3:0] ALUOp,   //ALU计算模式   
    output reg Jump,
    output reg Branch,//以上全部原本就有的接口都用作EXpipeline输出口
    output reg [4:0] ex_rs1, ex_rs2,wb_rd,
    output reg StallF, StallD, FlushD, FlushE,
    output reg [4:0] mem_rd
);
    reg id_RFWrite, id_DMCtrl, id_ALUSrcA, id_Jump, id_Branch;
    reg [1:0] id_ALUSrcB, id_RegSel, id_WDSel;
    reg [3:0] id_ALUOp;
    reg ex_RFWrite;
    reg ex_DMCtrl;
    reg mem_WDSel,ex_WDSel;
    reg [1:0] ALU_category ; //对ALU计算模式的细分
    reg [1:0] mem_RegSel,ex_RegSel;
    reg [4:0] ex_rd;
    always @(*) begin
        PCWrite  = 1'b1;           
        InsMemRW = 1'b1; 
        IRWrite  = 1'b1;    //上面都正常无气泡情况下默认正常输出运行
        id_RFWrite  = 1'b0;    //默认不写
        id_DMCtrl   = `DMCtrl_RD;     // 默认不写
        id_ALUSrcA  = `ALUSrcA_A;     // 默认rs1
        id_ALUSrcB  = `ALUSrcB_B;     // 默认rs2
        id_RegSel   = `RegSel_rd;     // 默认写回来源于rd
        id_WDSel    = `WDSel_FromALU; // 默认写回数据来自ALU
        NPCOp    = `NPC_PC;        // 默认+4
        ExtSel   = `ExtSel_SIGNED;   // 默认有符号拓展
        ALU_category = 2'b00;      // 默认用加法
        id_Jump     = 1'b0;
        id_Branch   = 1'b0;
        case (opcode)
            `INSTR_RTYPE_OP: begin
                id_RFWrite      = 1'b1;
                ALU_category = 2'b10; //即R型
            end
            `INSTR_ITYPE_OP: begin
                id_RFWrite      = 1'b1;
                id_ALUSrcB      = `ALUSrcB_Imm;
                ALU_category = 2'b11;        // 即I型，R&I要二次分类
            end
            `INSTR_LW_OP: begin
                id_RFWrite      = 1'b1;
                id_ALUSrcB      = `ALUSrcB_Imm; 
                id_WDSel        = `WDSel_FromMEM; 
                ALU_category = 2'b00;
            end
            `INSTR_SW_OP: begin
                id_DMCtrl       = `DMCtrl_WR;  
                id_ALUSrcB      = `ALUSrcB_Offset; 
                ALU_category = 2'b00;   
            end
            `INSTR_BTYPE_OP: begin
                ALU_category = 2'b01;
                NPCOp    = `NPC_Offset12;
                id_Branch   = 1'b1;
            end
            `INSTR_JAL_OP: begin
                id_RFWrite      = 1'b1;
                id_WDSel        = `WDSel_FromPC;  // 将 PC+4 写入 rd
                NPCOp        = `NPC_Offset20;  // 触发 JAL 跳转
                id_Jump         = 1'b1;
            end
            `INSTR_JALR_OP: begin
                id_RFWrite      = 1'b1;
                id_WDSel        = `WDSel_FromPC;  // 将 PC+4 写入 rd
                NPCOp        = `NPC_rs;        // 触发 JALR 跳转，且imm有符号
                id_ALUSrcB      = `ALUSrcB_Imm;
                id_Jump         = 1'b1;
            end
            default: ;
        endcase
end
always @(*) begin
    id_ALUOp = `ALUOp_ADD; 
    case (ALU_category)
        2'b00: id_ALUOp = `ALUOp_ADD; // Load/Store 算地址，统统用加法
        2'b01: id_ALUOp = `ALUOp_SUB; // 分支指令，统统用减法去比较
        2'b10: begin // 处理 R 型算术/逻辑指令
            case (Funct3)
                3'b000: id_ALUOp = (Funct7[5]) ? `ALUOp_SUB : `ALUOp_ADD; // add, sub
                3'b001: id_ALUOp = `ALUOp_SLL;                            // sll
                3'b100: id_ALUOp = `ALUOp_XOR;                            // xor
                3'b101: id_ALUOp = (Funct7[5]) ? `ALUOp_SRA : `ALUOp_SRL; // sra, srl
                3'b110: id_ALUOp = `ALUOp_OR;                             // or
                3'b111: id_ALUOp = `ALUOp_AND;                            // and
                default: id_ALUOp = `ALUOp_ADD;
            endcase
        end
        2'b11: begin 
            case (Funct3)
                `INSTR_ADDI_FUNCT: id_ALUOp = `ALUOp_ADD; // addi
                `INSTR_ORI_FUNCT:  id_ALUOp = `ALUOp_OR;  // ori
                default: id_ALUOp = `ALUOp_ADD;
            endcase
        end
    endcase
end

    always @(posedge clk or posedge rst) begin
        if (rst || FlushE) begin
            ALUOp <= 0; ALUSrcB <= 0; ex_WDSel <= 0; ex_RegSel <= 0;
            ALUSrcA <= 0; ex_DMCtrl <= 0; ex_RFWrite <= 0; Jump <= 0; Branch <= 0;
            ex_rs1 <= 0; ex_rs2 <= 0; ex_rd <= 0;
        end
        else begin
            ALUOp <= id_ALUOp; ALUSrcB <= id_ALUSrcB; 
            ex_WDSel <= id_WDSel; ex_RegSel <= id_RegSel; ALUSrcA <= id_ALUSrcA; 
            ex_DMCtrl <= id_DMCtrl; ex_RFWrite <= id_RFWrite; 
            Jump <= id_Jump; Branch <= id_Branch;
            ex_rs1 <= id_rs1; ex_rs2 <= id_rs2; ex_rd <= id_rd;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            DMCtrl  <= 0;
            mem_RFWrite <= 0;
            mem_WDSel   <= 0;
            mem_rd      <= 5'b0;
            mem_RegSel  <= 0;
        end 
        else begin
            // 数据往下级流动
            DMCtrl  <= ex_DMCtrl;
            mem_RFWrite <= ex_RFWrite;
            mem_WDSel   <= ex_WDSel;
            mem_rd      <= ex_rd;
            mem_RegSel  <= ex_RegSel;
        end
    end
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            RFWrite <= 0;
            RegSel  <= 0;
            wb_rd      <= 5'b0;
            WDSel   <= 0;
        end 
        else begin
            // 继续往下级流动
            RFWrite <= mem_RFWrite;
            RegSel  <= mem_RegSel; // 注意：RegSel 在 MEM 没用，可以直接从 EX 传到 WB，或者再加一级缓冲
            wb_rd      <= mem_rd;
            WDSel   <= mem_WDSel;
        end
    end
    
//——————冒险检测单元——————用always语句来搞个时序，好像就可以了//
    wire ID_is_Branch = (opcode == `INSTR_BTYPE_OP);
    wire id_reads_rs1 = (opcode != `INSTR_JAL_OP);
    wire id_reads_rs2 = (opcode == `INSTR_RTYPE_OP || opcode == `INSTR_SW_OP || ID_is_Branch);

    wire load_use_stall = !ex_DMCtrl && (ex_rd != 5'd0) && 
                          ((id_reads_rs1 && (ex_rd == id_rs1)) || 
                           (id_reads_rs2 && (ex_rd == id_rs2)));

    // 3. Branch 数据冒险检测 (极度硬核：分支指令在 ID 就需要数据)
    // 规则A: 前一条是 ALU 指令或 Load 指令，且目标寄存器就是 Branch 需要的，必须停顿1拍等它到 MEM
    wire branch_stall_EX  = ID_is_Branch && RFWrite && (ex_rd != 5'd0) && 
                            ((ex_rd == id_rs1) || (ex_rd == id_rs2));
    // 规则B: 前一条的前一条是 Load 指令，Branch 在 ID 阶段，Load 在 MEM 阶段，还没写回，停顿1拍
    wire branch_stall_MEM = ID_is_Branch && !DMCtrl && (mem_rd != 5'd0) && 
                            ((mem_rd == id_rs1) || (mem_rd == id_rs2));
    wire branch_stall = branch_stall_EX || branch_stall_MEM;

    wire Stall_Global = load_use_stall || branch_stall;
    
    always @(posedge clk or posedge rst) begin
        if(rst)begin
         StallF <= 0;
         StallD <= 0; 
         FlushE <= 0; 
         FlushD <= 0;
       end
       else begin
         StallF = Stall_Global;
         StallD = Stall_Global; 
         FlushE = Stall_Global; 
         FlushD = ID_Branch_Taken && !Stall_Global;
         end
     end
endmodule