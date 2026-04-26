`timescale 1ns / 1ps
module riscv(clk, rst);
    input clk, rst;

    wire RFWrite, DMCtrl, PCWrite, IRWrite, InsMemRW, ExtSel, zero, ALUSrcA;
    wire [1:0] ALUSrcB;
    wire [1:0] NPCOp, WDSel, RegSel;
    wire [3:0] ALUOp;
    wire [6:0] opcode;
    wire [2:0] Funct3;
    wire [6:0] Funct7;
    wire [31:0] PC, NPC, PCA4;
    wire [31:0] in_ins, out_ins, RD, DR_out;
    wire [4:0] rs1, rs2, rd, wb_rd;
    wire [11:0] Imm12;
    wire [31:0] Imm32,ex_imm32;
    wire [20:1] Offset20;
    wire [11:0] Offset,ex_Offset;
    wire [4:0] WR;
    wire [31:0] WD;
    wire [31:0] RD1, RD1_r, RD2, RD2_r,mem_RD2;
    wire [31:0] A, B, ALU_result, ALU_result_r;
    wire [31:0] id_PC;
    wire StallF,StallD,FlushE,FlushD;
    wire ID_Jump,ID_Branch;
    wire [4:0] ex_rs1, ex_rs2,mem_rd;
    wire ID_Branch_Taken;
    wire mem_RFWrite;

    assign opcode   = out_ins[6:0];
    assign Funct3   = out_ins[14:12];
    assign Funct7   = out_ins[31:25];
    assign rs1      = out_ins[19:15];
    assign rs2      = out_ins[24:20];
    assign rd       = out_ins[11:7];
    assign Imm12    = out_ins[31:20];
    assign Offset20 = {out_ins[31], out_ins[19:12], out_ins[20], out_ins[30:21]};
    assign Offset   = (opcode == `INSTR_BTYPE_OP) ? {out_ins[31], out_ins[7], out_ins[30:25], out_ins[11:8]} :
                      (opcode == `INSTR_SW_OP)   ? {out_ins[31:25], out_ins[11:7]} : Imm12;

    // ?     PC————IF阶段
    PC U_PC (
        .clk(clk), .rst(rst), .PCWrite(PCWrite), .NPC(NPC), .PC(PC),.FlushD(FlushD),.StallD(StallD),
        .id_PC(id_PC),.FlushE(FlushE),.StallF(StallF)   //呃呃，PCwrite可不可以当作stallD用啊，到时候研究一下啊
    );                                                  //PC直接输入到IM，PC在ID阶段不需要，直接传到EX阶段——不对，NPC决策提前了，传到ID
    
    // ?     IM
    IM U_IM (
        .addr(PC[11:2]), .Ins(in_ins), .InsMemRW(InsMemRW),.clk(clk)
    );//InsMemRW没什么用感觉，IM到时候想办法按SRAM标准改
    
        
    // ?     IR——需要好好研究的IR
    IR U_IR (
        .clk(clk), .IRWrite(IRWrite), .in_ins(in_ins), .out_ins(out_ins), .flush(FlushD),.stall(StallD),.rst(rst)
    );

    // ?     ControlUnit————ID
    ControlUnit U_ControlUnit(
        .clk(clk), .rst(rst), .zero(zero), .opcode(opcode), .Funct7(Funct7), .Funct3(Funct3),
        .RFWrite(RFWrite), .DMCtrl(DMCtrl), .PCWrite(PCWrite), .IRWrite(IRWrite), .InsMemRW(InsMemRW),//这三个是废物，不用管
        .ExtSel(ExtSel), .ALUOp(ALUOp), .NPCOp(NPCOp), .ALUSrcA(ALUSrcA),.mem_RFWrite(mem_RFWrite),
        .WDSel(WDSel), .ALUSrcB(ALUSrcB), .RegSel(RegSel),.id_rs1(rs1),.id_rs2(rs2), .id_rd(rd),
        .Jump(ID_Jump),.Branch(ID_Branch),.ex_rs1(ex_rs1),.ex_rs2(ex_rs2),.mem_rd(mem_rd),
        .ID_Branch_Taken(ID_Branch_Taken),.StallF(StallF),.StallD(StallD), .FlushD(FlushD), .FlushE(FlushE),.wb_rd(wb_rd)
    );//由于决策提前，NPCOp不需要传两级了,其余都是经过内部flopr传入EX或更远的
      //RFWrite貌似只需要最后WB的时候使用;DMCtrl只在mem需要使用；WDSel传到WB阶段；RegSel最终会传到WB;funct3_0用于分支判定，直接ID阶段NPC自取删除
      //ID_Branch_Taken由NPC传入；id_rs1/2给RF，ex_rs1/2给MUX前递；ex_rd用于cu内部冒险检测，不需要接口，rd是顶层的assign。最终会直通MUX，MUX应该
      //另开一个接口了,NPC需要mem_rd；mem_RfWrite也需要传入NPC
      
      
    // ?     RF
    RF U_RF (
        .RR1(rs1), .RR2(rs2), .WR(WR), .WD(WD), .clk(clk),
        .RFWrite(RFWrite), .RD1(RD1), .RD2(RD2)
    );//WR和WD是在WB阶段被写回的，不过RegSel和WDSel都是传到WB阶段，所以应该没问题；RFWrite由WBreg回到这里；

      
    // ?     NPC——现在NPC是ID的人了（
    NPC U_NPC (
        .PC(PC), .NPCOp(NPCOp), .Offset12(Offset), .Offset20(Offset20), .rs({RD1[31:2],2'b00}), .PCA4(PCA4), .NPC(NPC),
        .imm(Imm32),.id_PC(id_PC),.clk(clk),.rst(rst), .FlushE(FlushE),.ID_RD1(RD1), .ID_RD2(RD2),.funct3_0(Funct3[0]),
        .ID_rs1(rs1), .ID_rs2(rs2),.MEM_ALU_result(ALU_result_r),.MEM_rd(mem_rd),.MEM_RFWrite(mem_RFWrite),
        .ID_Branch_Taken(ID_Branch_Taken)
    );//PC由于跨阶段了，所以不要了），自己创造一个接口；PCA4直接去到WB阶段

    // ?     EXT
    EXT U_EXT (
        .imm_in(Imm12), .ExtSel(ExtSel), .imm_out(Imm32),.FlushE(FlushE),.ex_imm32(ex_imm32),.Offset20(Offset20),.Offset(Offset),
        .ex_Offset(ex_Offset),.clk(clk),.rst(rst)//不对，传入mux和alu的是原版的offse 和 offset20,Imm32需要给NPC算jalr
    );


    // ?     Flopr  ID_EX pipeline reg
    Flopr U_A (
        .clk(clk), .rst(rst), .in_data(RD1), .out_data(RD1_r),.CLR(FlushE),.Stall(1'b0)
    );

    // ?     Flopr
    Flopr U_B (
        .clk(clk), .rst(rst), .in_data(RD2), .out_data(RD2_r),.CLR(FlushE),.Stall(1'b0)
    );

    // ?     MUX_2to1_A，用于ALUA的来源
    MUX_2to1_A U_MUX_2to1_A (
        .X(RD1_r), .Y(5'h0), .control(ALUSrcA), .out(A),.mem_ALU_result(ALU_result_r),
        .wb_WD(WD),.ex_rs1(ex_rs1),.mem_rd(mem_rd),.wb_rd(wb_rd),
        .mem_RFWrite(mem_RFWrite), .wb_RFWrite(RFWrite)
    );

    // ?     MUX_3to1_B，用于ALUB的来源
    MUX_3to1_B U_MUX_3to1_B (
        .X(RD2_r), .Y(Imm32), .Z(Offset), .control(ALUSrcB), .out(B),.mem_ALU_result(ALU_result_r),.wb_WD(WD),.ex_rs2(ex_rs2), 
        .mem_rd(mem_rd), .wb_rd(wb_rd),.mem_RFWrite(mem_RFWrite), .wb_RFWrite(RFWrite),//这个offset估计得弃掉,这个Imm32也得弃掉
        .Y_2(ex_imm32),.Z_2(ex_Offset),.Forwarded_Data_mem(mem_RD2),
         .clk(clk), .rst(rst)
    );

    // ?     ALU
    ALU U_ALU (
        .A(A), .B(B), .ALUOp(ALUOp), .ALU_result(ALU_result), .zero(zero)
    );//RD2_r需要传入EX的MUX模块内，也需要传入DM内部，所以靠ALU多打一拍。

    // ?     Flopr————按理来说EX/MEM，所以最后的MUX我觉得应该另寻蹊跷了（
    Flopr U_ALUOut (
        .clk(clk), .rst(rst), .in_data(ALU_result), .out_data(ALU_result_r),.CLR(1'b0),.Stall(1'b0)
    );

    // ?     DM
    DM U_DM (
        .Addr(ALU_result_r[11:2]), .WD(RD2_r), .DMCtrl(DMCtrl), .clk(clk), .RD(RD),.WD2(mem_RD2)
    );//ALU_result_r只用于这一处，其他另辟蹊径；WD不能用了，传送的是EX的，把内部WD相关数据替换为了mem_RD2
      //RD实际上就是WB的，DM作为flopr之一
    
        // ?     MUX_3to1----WB
    MUX_3to1 U_MUX_3to1 (
        .X(rd), .Y(5'd0), .Z(5'd31),
        .control(RegSel), .out(WR),.wb_rd(wb_rd)
    );//rd由于是胶水逻辑，不能使用；WR传到RF；X的逻辑全部换成了wb_rd

    // ?     MUX_3to1_LMD
    MUX_3to1_LMD U_MUX_3to1_LMD (
        .X(ALU_result_r), .Y(DR_out), .Z(PCA4),
        .control(WDSel), .out(WD), .clk(clk), .rst(rst)
    );//ALU_result_r在这里不能用了（恼）;不对，照样可以，ALU_result_r输入进去后用个flopr打一拍就可以了
    
    assign DR_out = RD;
endmodule