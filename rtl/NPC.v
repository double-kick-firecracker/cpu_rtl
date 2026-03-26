`include "ctrl_signal_def.v"
`include "instruction_def.v"
module NPC(NPCOp, Offset12, Offset20, PC, rs, PCA4, NPC);
    input  [1:0]  NPCOp;     //控制信号
    input  [12:1] Offset12;  //比较指令的跳转偏移量
    input  [20:1] Offset20;  //跳转指令的跳转偏移量
    input  [31:0] PC;        //本条指令的地址
    input  [31:0] rs;        //跳转到子程序的地址
    output reg [31:0] PCA4;  //PC+4
    output reg [31:0] NPC;   //下一条指令的地址

    wire signed [12:0] Offset13;
    wire signed [20:0] Offset21;

    assign Offset13 = $signed({Offset12[12:1], 1'b0});  //实际为13位
    assign Offset21 = $signed({Offset20[20:1], 1'b0});  //实际为21位

    always@(*) begin
        case(NPCOp)
            `NPC_PC      : NPC = PC + 4;                          //顺序执行，32位CPU，地址每次加4
            `NPC_Offset12: NPC = $signed({1'b0, PC}) + $signed(Offset13);  //指令地址跳转
            `NPC_rs      : NPC = rs;                              //指令地址跳转为rs
            `NPC_Offset20: NPC = $signed({1'b0, PC}) + $signed(Offset21);  //指令地址跳转
        endcase
        PCA4 = PC + 4;
    end
endmodule