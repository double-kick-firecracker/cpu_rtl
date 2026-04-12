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
    wire StallF,StallD;
    
    assign IF_PC_plus_4 = IF_PC + 32'd4; 
    assign NPC = EX_Control_Taken ? EX_NPC_Target : IF_PC_plus_4;
    PC U_PC (
        .clk(clk), .rst(rst), .PCWrite(PCWrite), .NPC(NPC), .PC(IF_PC), .stall(StallF)
    );
    
    IM U_IM (
        .addr(IF_PC[11:2]), .Ins(in_ins), .InsMemRW(InsMemRW), .clk(clk), .stall(StallD)
    );
    
//——————IF到ID的寄存器——————//
    wire [31:0] out_ins; 
    wire [31:0] ID_PC;
    wire FlushD;
    Flopr U_IF_ID_PC (
        .clk(clk), .rst(rst), .in_data(IF_PC), .out_data(ID_PC), .CLR(FlushD), .Stall(StallD)
    );      
                
    IR U_IR (
        .clk(clk), .IRWrite(IRWrite), .in_ins(in_ins), .out_ins(out_ins), .flush(FlushD)
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
    wire [4:0] rs1, rs2,rd;
    wire ID_Jump, ID_Branch;
    wire [20:1] Offset20;
    wire [11:0] Offset;
    wire [4:0] ID_rs1;
    wire [4:0] ID_rs2;
    
    assign opcode   = out_ins[6:0];
    assign Funct3   = out_ins[14:12];
    assign Funct7   = out_ins[31:25];
    assign rs1      = out_ins[19:15];
    assign rs2      = out_ins[24:20];
    assign Imm12    = out_ins[31:20];
    assign rd       = out_ins[11:7];
    assign ID_rs1   = out_ins[19:15];
    assign ID_rs2   = out_ins[24:20];
    
    assign Offset20 = {out_ins[31], out_ins[19:12], out_ins[20], out_ins[30:21]};//jal--需要传入到NPC中，
    assign Offset   = (opcode == `INSTR_BTYPE_OP) ? {out_ins[31], out_ins[7], out_ins[30:25], out_ins[11:8]} :
                      (opcode == `INSTR_SW_OP)   ? {out_ins[31:25], out_ins[11:7]} : Imm12;  //会在MUX3-1内部符号拓展
                      
    wire [31:0] ID_Offset_Packed;
    assign ID_Offset_Packed = {Offset20, Offset};

    ControlUnit U_ControlUnit(
        .clk(clk), .rst(rst), .zero(1'b0), .opcode(opcode), .Funct7(Funct7), .Funct3(Funct3),//zero貌似悬空了，不知道影不影响，先给一个const
        .RFWrite(RFWrite), .DMCtrl(DMCtrl), .PCWrite(PCWrite), .IRWrite(IRWrite), .InsMemRW(InsMemRW), 
        .ExtSel(ExtSel), .ALUOp(ALUOp), .NPCOp(NPCOp), .ALUSrcA(ALUSrcA), .WDSel(WDSel),
        .ALUSrcB(ALUSrcB), .RegSel(RegSel), .Jump(ID_Jump), .Branch(ID_Branch)
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
    wire [31:0] EX_PC, EX_Imm32, EX_Inst, EX_RD1, EX_RD2, EX_Offset_Packed;
    wire FlushE;
    
    Flopr U_A         ( .clk(clk), .rst(rst), .in_data(RD1),     .out_data(EX_RD1),.CLR(FlushE), .Stall(1'b0) );
    Flopr U_B         ( .clk(clk), .rst(rst), .in_data(RD2),     .out_data(EX_RD2),.CLR(FlushE), .Stall(1'b0) );
    Flopr U_IDEX_PC   ( .clk(clk), .rst(rst), .in_data(ID_PC),   .out_data(EX_PC),.CLR(FlushE), .Stall(1'b0) );
    Flopr U_IDEX_IMM  ( .clk(clk), .rst(rst), .in_data(Imm32),   .out_data(EX_Imm32) ,.CLR(FlushE), .Stall(1'b0));
    Flopr U_IDEX_OFFSET ( .clk(clk), .rst(rst), .in_data(ID_Offset_Packed), .out_data(EX_Offset_Packed),.CLR(FlushE), .Stall(1'b0) );
    
    wire       ID_funct3_0 = out_ins[12]; // 用来区别btype
    
    reg [32:0] id_ex_ctrl_reg;
    always @(posedge clk or posedge rst) begin
        if (rst) 
            id_ex_ctrl_reg <= 33'b0;
        else 
            id_ex_ctrl_reg <= {
                ID_rs1,ID_rs2,
                ID_Branch, ID_Jump, ID_funct3_0, rd,          
                ALUOp, NPCOp, ALUSrcB, ALUSrcA,               
                DMCtrl, RFWrite, WDSel, RegSel                
            };
    end
    
//——————EXE——————//
    wire [4:0] EX_rs1 = id_ex_ctrl_reg[32:28];
    wire [4:0] EX_rs2 = id_ex_ctrl_reg[27:23];
    wire EX_Branch      = id_ex_ctrl_reg[22];
    wire EX_Jump        = id_ex_ctrl_reg[21];
    wire EX_funct3_0    = id_ex_ctrl_reg[20];
    wire [4:0] EX_rd    = id_ex_ctrl_reg[19:15];
    wire [3:0] EX_ALUOp = id_ex_ctrl_reg[14:11];
    wire [1:0] EX_NPCOp = id_ex_ctrl_reg[10:9];
    wire EX_ALUSrcB     = id_ex_ctrl_reg[8:7];
    wire EX_ALUSrcA     = id_ex_ctrl_reg[6];
    wire EX_DMCtrl      = id_ex_ctrl_reg[5];
    wire EX_RFWrite     = id_ex_ctrl_reg[4];
    wire [1:0]EX_WDSel  = id_ex_ctrl_reg[3:2]; 
    wire [1:0]EX_RegSel = id_ex_ctrl_reg[1:0];
    wire [19:0] EX_Offset20 = EX_Offset_Packed[31:12];
    wire [11:0] EX_Offset12 = EX_Offset_Packed[11:0];

    wire [31:0] A, B, ALU_result;
    wire zero;
    wire [31:0] PCA4;                  
    NPC U_NPC (
        .PC(EX_PC), .NPCOp(EX_NPCOp), .Offset12(Offset), .Offset20(Offset20), .rs({Forwarded_A[31:2],2'b00}),
        .imm(EX_Imm32), .PCA4(PCA4),.NPC(EX_NPC_Target)//修改了rs接入的数
    );
    
    wire [31:0] Forwarded_A;
    wire [31:0] Forwarded_B;//包含了前递情况的预先声明
    
    // 实例化 MUX_2to1_A——决定ALUA的操作数来源
    MUX_2to1_A U_MUX_2to1_A (
        .X(Forwarded_A), .Y(32'h0), .control(EX_ALUSrcA), .out(A)
    );

    // 实例化 MUX_3to1_B——ALUB的操作数来源
    MUX_3to1_B U_MUX_3to1_B (
        .X(Forwarded_B), .Y(EX_Imm32), .Z(Offset), .control(EX_ALUSrcB), .out(B)
    );

    // 实例化 ALU
    ALU U_ALU (
        .A(A), .B(B), .ALUOp(EX_ALUOp), .ALU_result(ALU_result), .zero(zero)
    );
    
    // 分支判定 (反馈给 IF 阶段)
    wire EX_Branch_Cond_Met = (EX_funct3_0 == 1'b1) ? ~zero : zero;
    assign EX_Control_Taken = EX_Jump || (EX_Branch && EX_Branch_Cond_Met);

//————————EX/MEM——————//
    wire [31:0] MEM_ALU_result, MEM_RD2, MEM_PCA4, MEM_Inst, mem_ctrl;
    
    reg [10:0] ex_mem_ctrl_reg;
    always @(posedge clk or posedge rst) begin
        if (rst) ex_mem_ctrl_reg <= 11'b0;
        else ex_mem_ctrl_reg <= {
            EX_rd,                              // [10:6] 5位
            EX_DMCtrl, EX_RFWrite,              // [5:4]  2位
            EX_WDSel, EX_RegSel                 // [3:0]  4位
        };
    end
    
    Flopr U_ALUOut (.clk(clk), .rst(rst), .in_data(ALU_result), .out_data(MEM_ALU_result),.CLR(1'b0), .Stall(1'b0));
    Flopr U_EXMEM_RD2  ( .clk(clk), .rst(rst), .in_data(Forwarded_B),     .out_data(MEM_RD2),.CLR(1'b0), .Stall(1'b0) );
    Flopr U_EXMEM_PCA4 ( .clk(clk), .rst(rst), .in_data(PCA4),    .out_data(MEM_PCA4),.CLR(1'b0), .Stall(1'b0) );
    
//————————MEM————————//
    wire [4:0] MEM_rd      = ex_mem_ctrl_reg[10:6];
    wire       MEM_DMCtrl  = ex_mem_ctrl_reg[5];
    wire       MEM_RFWrite = ex_mem_ctrl_reg[4];
    wire [1:0] MEM_WDSel   = ex_mem_ctrl_reg[3:2];
    wire [1:0] MEM_RegSel  = ex_mem_ctrl_reg[1:0];
    wire [31:0] RD;
    
    // 实例化 DM
    DM U_DM (
        .Addr(MEM_ALU_result[11:2]), .WD(MEM_RD2), .DMCtrl(MEM_DMCtrl), .clk(clk), .RD(RD)
    );
//————————MEM/WB————————//
    wire [31:0] WB_ALU_result, WB_PCA4;
    
    reg [9:0] mem_wb_ctrl_reg;
    always @(posedge clk or posedge rst) begin
        if (rst) mem_wb_ctrl_reg <= 10'b0;
        else mem_wb_ctrl_reg <= {
            MEM_rd,                             // [9:5] 5位
            MEM_RFWrite, MEM_WDSel, MEM_RegSel  // [4:0] 5位
        };
        end

    Flopr U_MEMWB_ALU  ( .clk(clk), .rst(rst), .in_data(MEM_ALU_result), .out_data(WB_ALU_result),.CLR(1'b0), .Stall(1'b0) );
    Flopr U_MEMWB_PCA4 ( .clk(clk), .rst(rst), .in_data(MEM_PCA4),       .out_data(WB_PCA4),.CLR(1'b0), .Stall(1'b0) );
    
//————————WB————————//
    wire [4:0] WB_rd      = mem_wb_ctrl_reg[9:5];
    assign     WB_RFWrite = mem_wb_ctrl_reg[4];
    wire [1:0] WB_WDSel   = mem_wb_ctrl_reg[3:2];
    wire [1:0] WB_RegSel  = mem_wb_ctrl_reg[1:0];
    
    // 实例化 MUX_3to1_LMD--决定写回什么数据
    MUX_3to1_LMD U_MUX_3to1_LMD (
        .X(WB_ALU_result), .Y(RD), .Z(WB_PCA4[31:2]), .Z_(WB_PCA4[1:0]),
        .control(WB_WDSel), .out(WB_WD)
    );
    
    // 实例化 MUX_3to1--决定写回地址
    MUX_3to1 U_MUX_3to1 (
        .X(WB_rd), .Y(5'd0), .Z(5'd31),
        .control(WB_RegSel), .out(WB_WR)
    );
    
//————————harzard unit————————//
    wire EX_is_Load = (id_ex_ctrl_reg[3:2] == 2'b01); //看看WDSel最终写回的是哪里的数据
    wire Load_Use_Stall = EX_is_Load && (EX_rd != 5'd0) && ((EX_rd == ID_rs1) || (EX_rd == ID_rs2));
    
    assign StallF = EX_is_Load;                       // 暂停 PC
    assign StallD = EX_is_Load;                       // 暂停 IF/ID
    assign FlushE = EX_is_Load || EX_Control_Taken;   // 清空 ID/EX (LoadUse时变气泡，跳错时也变气泡)
    assign FlushD = EX_Control_Taken;              // 清空 IF/ID (只有跳错时需要清空)

//——————forward——————//
    wire [1:0] ForwardA;
    wire [1:0] ForwardB;
        
    assign ForwardA = (rst == 1'b0) ? 2'b00 : 
                       ((MEM_RFWrite == 1'b1) & (MEM_rd != 5'h00) & (MEM_rd == EX_rs1)) ? 2'b10 :
                       ((WB_RFWrite == 1'b1) & (WB_rd != 5'h00) & (WB_rd == EX_rs1)) ? 2'b01 : 2'b00;
                       
    assign ForwardB = (rst == 1'b0) ? 2'b00 : 
                       ((MEM_RFWrite == 1'b1) & (MEM_rd != 5'h00) & (MEM_rd == EX_rs2)) ? 2'b10 :
                       ((WB_RFWrite == 1'b1) & (WB_rd != 5'h00) & (WB_rd == EX_rs2)) ? 2'b01 : 2'b00;
    
    assign Forwarded_A = (ForwardA == 2'b10) ? MEM_ALU_result :
                         (ForwardA == 2'b01) ? WB_WD : EX_RD1;

    assign Forwarded_B = (ForwardB == 2'b10) ? MEM_ALU_result :
                         (ForwardB == 2'b01) ? WB_WD : EX_RD2;
    
endmodule
