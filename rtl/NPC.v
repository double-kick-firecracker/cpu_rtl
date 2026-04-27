`include "ctrl_signal_def.v"
`include "instruction_def.v"
module NPC(NPCOp, Offset12, Offset20, PC, rs, imm, PCA4, NPC,funct3_0,ex_PC,
           EX_Jump_Taken,clk, rst, A, B,ex_Offset,ex_Offset20,ex_imm32);
    input  [1:0]  NPCOp;     //控制信号
    input  [12:1] Offset12,ex_Offset;  //SB指令的跳转偏移量
    input  [20:1] Offset20,ex_Offset20;  //JAL指令的跳转偏移量
    input  [31:0] PC,ex_PC,A,B;        //本条指令的地址——PC在打拍递增上还是有用的
    input  [31:0] rs;        //跳转到子程序的地址
    input  [31:0] imm,ex_imm32;       //用于计算jalr的偏移地址，经过了ext的拓展
    output reg [31:0] PCA4;  //PC+4，把它作为最终WBreg出来的PC4
    output reg [31:0] NPC;   //下一条指令的地址
    input clk, rst;
    input funct3_0;//要靠某个器件传一个funct3_0
    output EX_Jump_Taken; // 告诉 ControlUnit 分支是否成立，用于 Flush IF
    
    wire [31:0] mem_PCA4; // 顺带打拍传递给下一级的 PC+4

    wire signed [12:0] Offset13;
    wire signed [20:0] Offset21;
    reg [31:0] ex_PCA4;
    
    wire is_equal     = (A == B);
    wire is_not_equal = (A != B);

    wire branch_condition_met;
    assign branch_condition_met = funct3_0 ? is_not_equal : is_equal;

    assign EX_Jump_Taken = (NPCOp == 2'b01 && branch_condition_met) || (NPCOp == 2'b10) || (NPCOp == 2'b11);
    
    assign Offset13 = $signed({ex_Offset[12:1], 1'b0});  //实际为13位
    assign Offset21 = $signed({ex_Offset20[20:1], 1'b0});  //实际为21位
    
    reg [31:0] jump_target;

    always@(*) begin
        case(NPCOp)
            `NPC_PC      : jump_target = ex_PC + 4;//感觉是没什么用了
            `NPC_Offset12: jump_target = branch_condition_met ? ($signed({1'b0, ex_PC}) + $signed(Offset13)) : (ex_PC + 4);  //sb指令地址跳转，PC一直是正数，要加个0语法糖防止它变成负数
            `NPC_rs      : jump_target = A + ex_imm32;                              //指令地址跳转为rs，jalr要改逻辑加个imm
            `NPC_Offset20: jump_target = $signed({1'b0, ex_PC}) + $signed(Offset21);  //jal指令地址跳转
            default      : jump_target = ex_PC + 4; //单纯防锁存
        endcase
        ex_PCA4 = ex_PC + 4;//单纯是用来给写回
    end
    
    wire [31:0] NPC_4=PC+4;
    
    always @(*) begin
        if (EX_Jump_Taken) begin
            NPC = jump_target; // 发生跳转，把 ID 算出来的跳转地址扔给顶层 PC
        end else begin
            NPC = NPC_4; // 不跳转，把 IF 算出来的 PC+4 扔给顶层 PC
        end
    end
    
    Flopr U_EX_MEM_PCA4 ( .clk(clk), .rst(rst), .in_data(ex_PCA4),.out_data(mem_PCA4),.CLR(1'b0), .Stall(1'b0) );
    always @(posedge clk or posedge rst) begin
        if(rst)
            PCA4 <= 0;    //复位后，输出为0
        else
            PCA4 <= mem_PCA4;  //将输入数据输出
    end
    
endmodule