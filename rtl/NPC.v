`include "ctrl_signal_def.v"
`include "instruction_def.v"
module NPC(NPCOp, Offset12, Offset20, PC, rs, imm, PCA4, NPC,ID_RD1, ID_RD2,funct3_0,id_PC,
           ID_rs1, ID_rs2,MEM_ALU_result,MEM_rd,MEM_RFWrite,ID_Branch_Taken,clk, rst, FlushE);
    input  [1:0]  NPCOp;     //控制信号
    input  [12:1] Offset12;  //SB指令的跳转偏移量
    input  [20:1] Offset20;  //JAL指令的跳转偏移量
    input  [31:0] PC,id_PC;        //本条指令的地址——PC可能要被舍弃掉了，因为跨了一个流水线
    input  [31:0] rs;        //跳转到子程序的地址
    input  [31:0] imm;       //用于计算jalr的偏移地址，经过了ext的拓展
    output reg [31:0] PCA4;  //PC+4，把它作为最终WBreg出来的PC4
    output reg [31:0] NPC;   //下一条指令的地址
    input clk, rst, FlushE;
    input [31:0] ID_RD1, ID_RD2;
    input [4:0]  ID_rs1, ID_rs2;
    input [31:0] MEM_ALU_result; // ID 阶段专用的前递数据源 (注意：EX产生的数据已被stall屏蔽，这里主要接MEM阶段)
    input [4:0]  MEM_rd;
    input funct3_0;
    input MEM_RFWrite;
    output ID_Branch_Taken; // 告诉 ControlUnit 分支是否成立，用于 Flush IF
    
    wire [31:0] mem_PCA4,ex_PCA4; // 顺带打拍传递给下一级的 PC+4

    wire signed [12:0] Offset13;
    wire signed [20:0] Offset21;
    reg [31:0] id_PCA4;
    
    wire forward_A_ID = (MEM_RFWrite && (MEM_rd != 5'd0) && (MEM_rd == ID_rs1));
    wire forward_B_ID = (MEM_RFWrite && (MEM_rd != 5'd0) && (MEM_rd == ID_rs2));

    wire [31:0] cmp_A = forward_A_ID ? MEM_ALU_result : ID_RD1;
    wire [31:0] cmp_B = forward_B_ID ? MEM_ALU_result : ID_RD2;
    
    wire is_equal     = (cmp_A == cmp_B);
    wire is_not_equal = (cmp_A != cmp_B);

    wire branch_condition_met;
    assign branch_condition_met = funct3_0 ? is_not_equal : is_equal;

    assign ID_Branch_Taken = (NPCOp == 2'b01 && branch_condition_met) || (NPCOp == 2'b10) || (NPCOp == 2'b11);
    
    assign Offset13 = $signed({Offset12[12:1], 1'b0});  //实际为13位
    assign Offset21 = $signed({Offset20[20:1], 1'b0});  //实际为21位

    always@(*) begin
        case(NPCOp)
            `NPC_PC      : NPC = id_PC + 4;                          //顺序执行，32位CPU，地址每次加4——改流水线后已经冗余了
            `NPC_Offset12: NPC = branch_condition_met ? ($signed({1'b0, id_PC}) + $signed(Offset13)) : (id_PC + 4);  //sb指令地址跳转，PC一直是正数，要加个0语法糖防止它变成负数
            `NPC_rs      : NPC = rs + imm;                              //指令地址跳转为rs，jalr要改逻辑加个imm
            `NPC_Offset20: NPC = $signed({1'b0, id_PC}) + $signed(Offset21);  //jal指令地址跳转
            default      : NPC = id_PC + 4; 
        endcase
        id_PCA4 = id_PC + 4;//单纯是用来给写回
    end
    
    Flopr U_ID_EX_PCA4 ( .clk(clk), .rst(rst), .in_data(id_PCA4), .out_data(ex_PCA4),.CLR(FlushE), .Stall(1'b0) );
    Flopr U_EX_MEM_PCA4 ( .clk(clk), .rst(rst), .in_data(ex_PCA4),.out_data(mem_PCA4),.CLR(FlushE), .Stall(1'b0) );
    always @(posedge clk or posedge rst) begin
        if(rst)
            PCA4 <= 0;    //复位后，输出为0
        else if(FlushE)
            PCA4 <= 32'h0000_0013;
        else
            PCA4 <= mem_PCA4;  //将输入数据输出
    end
    
endmodule