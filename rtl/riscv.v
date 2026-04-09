`timescale 1ns / 1ps

module riscv(clk, rst);
    input clk, rst;
        
//——————————IF————————// 
    wire        EX_Control_Taken; // EX 阶段判断的结果：是否真要跳转 (Branch Taken 或 JAL/JALR)
    wire [31:0] EX_NPC_Target;    // EX 阶段 (NPC模块) 计算出的跳转目标地址
    wire [31:0] IF_PC;
    wire [31:0] IF_PC_plus_4;
    wire [31:0] in_ins;
    wire [31:0] NPC;
    wire IRWrite, PCWrite, InsMemRW;
    
    assign IF_PC_plus_4 = IF_PC + 32'd4; 
    assign NPC = EX_Control_Taken ? EX_NPC_Target : IF_PC_plus_4;
    PC U_PC (
        .clk(clk), .rst(rst), .PCWrite(PCWrite), .NPC(NPC), .PC(IF_PC)
    );
    
    IM U_IM (
        .addr(IF_PC[11:2]), .Ins(in_ins), .InsMemRW(InsMemRW)
    );
    
//——————IF到ID的寄存器——————//
    wire [31:0] out_ins; 
    wire [31:0] ID_PC;
    Flopr U_IF_ID_PC (
        .clk(clk), .rst(rst), .in_data(IF_PC), .out_data(ID_PC)
    );      
                
    IR U_IR (
        .clk(clk), .IRWrite(IRWrite), .in_ins(in_ins), .out_ins(out_ins)
    );   
    
//————————ID——————// 
    wire [1:0] NPCOp, WDSel, RegSel;
    wire [3:0] ALUOp;
    wire [6:0] opcode;
    wire [2:0] Funct3;
    wire [6:0] Funct7;
    wire [1:0] ALUSrcB;
    wire RFWrite, DMCtrl, ExtSel,ALUSrcA;
    wire [11:0] Imm12;
    wire [31:0] Imm32;
    wire [4:0] rs1, rs2;
    
    assign opcode   = out_ins[6:0];
    assign Funct3   = out_ins[14:12];
    assign Funct7   = out_ins[31:25];
    assign rs1      = out_ins[19:15];
    assign rs2      = out_ins[24:20];
    assign Imm12    = out_ins[31:20];

    ControlUnit U_ControlUnit(
        .clk(clk), .rst(rst), .zero(1'b0), .opcode(opcode), .Funct7(Funct7), .Funct3(Funct3),//zero貌似悬空了，不知道影不影响，先给一个const
        .RFWrite(RFWrite), .DMCtrl(DMCtrl), .PCWrite(PCWrite), .IRWrite(IRWrite), .InsMemRW(InsMemRW), 
        .ExtSel(ExtSel), .ALUOp(ALUOp), .NPCOp(NPCOp), .ALUSrcA(ALUSrcA),          
        .WDSel(WDSel), .ALUSrcB(ALUSrcB), .RegSel(RegSel)
    );
    
    wire [4:0] WB_WR;
    wire [31:0] WB_WD;
    wire WB_RFWrite;
    wire [31:0] RD1, RD2;
    
    RF U_RF (
        .RR1(rs1), .RR2(rs2), .WR(WB_WR), .WD(WB_WD), .clk(clk),//WR、WD和RFWrite应该是由WB阶段传回来的才行
        .RFWrite(WB_RFWrite), .RD1(RD1), .RD2(RD2)
    ); 

    EXT U_EXT (
        .imm_in(Imm12), .ExtSel(ExtSel), .imm_out(Imm32)
    );
    
//————————ID/EXE————————//
    wire [31:0] EX_PC, EX_Imm32, EX_Inst, EX_RD1, EX_RD2;
    
    Flopr U_A         ( .clk(clk), .rst(rst), .in_data(RD1),     .out_data(EX_RD1) );
    Flopr U_B         ( .clk(clk), .rst(rst), .in_data(RD2),     .out_data(EX_RD2) );
    Flopr U_IDEX_PC   ( .clk(clk), .rst(rst), .in_data(ID_PC),   .out_data(EX_PC) );
    Flopr U_IDEX_IMM  ( .clk(clk), .rst(rst), .in_data(Imm32),   .out_data(EX_Imm32) );
    Flopr U_IDEX_INST ( .clk(clk), .rst(rst), .in_data(out_ins), .out_data(EX_Inst) );

    // 打包控制信号 (ID -> EX)
    wire [31:0] id_ctrl_pack = {17'b0, ALUOp, NPCOp, ALUSrcB, ALUSrcA, DMCtrl, RFWrite, WDSel, RegSel};
    // 位域分布: [14:11]ALUOp, [10:9]NPCOp, [8:7]ALUSrcB, [6]ALUSrcA, [5]DMCtrl, [4]RFWrite, [3:2]WDSel, [1:0]RegSel
    wire [31:0] ex_ctrl;
    Flopr U_IDEX_CTRL ( .clk(clk), .rst(rst), .in_data(id_ctrl_pack), .out_data(ex_ctrl) );
    
//——————EXE——————//
    wire [20:1] Offset20;
    wire [11:0] Offset;
    wire [6:0]  EX_opcode;   
    
    assign EX_opcode = EX_Inst[6:0];
    assign Offset20 = {EX_Inst[31], EX_Inst[19:12], EX_Inst[20], EX_Inst[30:21]};//jal--需要传入到NPC中，
    assign Offset   = (EX_opcode == `INSTR_BTYPE_OP) ? {EX_Inst[31], EX_Inst[7], EX_Inst[30:25], EX_Inst[11:8]} :
                      (EX_opcode == `INSTR_SW_OP)   ? {EX_Inst[31:25], EX_Inst[11:7]} : EX_Inst[31:20];  //会在MUX3-1内部符号拓展
                      
    // 提取 EX 阶段需要的控制信号
    wire [3:0] EX_ALUOp   = ex_ctrl[14:11];
    wire [1:0] EX_NPCOp   = ex_ctrl[10:9];
    wire [1:0] EX_ALUSrcB = ex_ctrl[8:7];
    wire       EX_ALUSrcA = ex_ctrl[6];

    wire [31:0] A, B, ALU_result;
    wire zero;
    wire [31:0] PCA4;                  
    NPC U_NPC (
        .PC(EX_PC), .NPCOp(EX_NPCOp), .Offset12(Offset), .Offset20(Offset20), .rs({EX_RD1[31:2],2'b00}),
        .imm(EX_Imm32), .PCA4(PCA4),.NPC(EX_NPC_Target)//修改了rs接入的数
    );
    
    // 实例化 MUX_2to1_A——决定ALUA的操作数来源
    MUX_2to1_A U_MUX_2to1_A (
        .X(EX_RD1), .Y(32'h0), .control(EX_ALUSrcA), .out(A)
    );

    // 实例化 MUX_3to1_B——ALUB的操作数来源
    MUX_3to1_B U_MUX_3to1_B (
        .X(EX_RD2), .Y(EX_Imm32), .Z(Offset), .control(EX_ALUSrcB), .out(B)
    );

    // 实例化 ALU
    ALU U_ALU (
        .A(A), .B(B), .ALUOp(EX_ALUOp), .ALU_result(ALU_result), .zero(zero)
    );
    
    // 分支判定 (反馈给 IF 阶段)
    wire EX_is_Branch = (EX_opcode == `INSTR_BTYPE_OP);//其实可以在CU里面加接口JUMP和BRANCH传过来，不知道哪个更方便更省面积
    wire EX_is_Jump   = (EX_opcode == `INSTR_JAL_OP) || (EX_opcode == `INSTR_JALR_OP);
    wire EX_Branch_Cond_Met = (EX_Inst[12] == 1'b1) ? ~zero : zero;
    assign EX_Control_Taken = EX_is_Jump || (EX_is_Branch && EX_Branch_Cond_Met);

//————————EX/MEM——————//
    wire [31:0] MEM_ALU_result, MEM_RD2, MEM_PCA4, MEM_Inst, mem_ctrl;
    
    Flopr U_ALUOut (
        .clk(clk), .rst(rst), .in_data(ALU_result), .out_data(MEM_ALU_result)
    );
    Flopr U_EXMEM_RD2  ( .clk(clk), .rst(rst), .in_data(EX_RD2),     .out_data(MEM_RD2) );
    Flopr U_EXMEM_PCA4 ( .clk(clk), .rst(rst), .in_data(PCA4),    .out_data(MEM_PCA4) );
    Flopr U_EXMEM_INST ( .clk(clk), .rst(rst), .in_data(EX_Inst),    .out_data(MEM_Inst) );//一直在传inst确实有点浪费了，没必要
    Flopr U_EXMEM_CTRL ( .clk(clk), .rst(rst), .in_data(ex_ctrl),    .out_data(mem_ctrl) );
    
//————————MEM————————//
    wire MEM_DMCtrl = mem_ctrl[5]; // 提取 MEM 写使能
    wire [31:0] RD;
    // 实例化 DM
    DM U_DM (
        .Addr(MEM_ALU_result[11:2]), .WD(MEM_RD2), .DMCtrl(DMCtrl), .clk(clk), .RD(RD)
    );
//————————MEM/WB————————//
    wire [31:0] WB_ALU_result, WB_PCA4, WB_Inst, wb_ctrl;

    Flopr U_MEMWB_ALU  ( .clk(clk), .rst(rst), .in_data(MEM_ALU_result), .out_data(WB_ALU_result) );
    Flopr U_MEMWB_PCA4 ( .clk(clk), .rst(rst), .in_data(MEM_PCA4),       .out_data(WB_PCA4) );
    Flopr U_MEMWB_INST ( .clk(clk), .rst(rst), .in_data(MEM_Inst),       .out_data(WB_Inst) );
    Flopr U_MEMWB_CTRL ( .clk(clk), .rst(rst), .in_data(mem_ctrl),       .out_data(wb_ctrl) );
    
//————————WB————————//
    wire [4:0] WB_rd = WB_Inst[11:7]; // 最终的写回目的寄存器
    
    // 提取 WB 阶段控制信号
    assign WB_RFWrite    = wb_ctrl[4];
    wire [1:0] WB_WDSel  = wb_ctrl[3:2];
    wire [1:0] WB_RegSel = wb_ctrl[1:0];
    
    // 实例化 MUX_3to1_LMD--决定写回什么数据
    MUX_3to1_LMD U_MUX_3to1_LMD (
        .X(WB_ALU_result), .Y(RD), .Z(WB_PCA4),
        .control(WB_WDSel), .out(WB_WD)
    );
    
    // 实例化 MUX_3to1--决定写回地址
    MUX_3to1 U_MUX_3to1 (
        .X(WB_rd), .Y(5'd0), .Z(5'd31),
        .control(WB_RegSel), .out(WB_WR)
    );
    
endmodule
