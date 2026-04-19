`timescale 1ns / 1ps

`include "ctrl_signal_def.v"
module PC(clk, rst, PCWrite,stall, NPC, PC,Update_En,Update_PC,Update_Target,Update_Taken,Mispredict_Real);
    input         clk;        //时钟信号
    input         rst;        //复位信号
    input         PCWrite;    //PC写使能信号
    input  [31:0] NPC;        //下条指令的地址
    input         stall;
    output reg [31:0] PC;      //本条指令地址
    // --- 新增：来自 ID/EX 决断阶段的校验与更新信号 ---
    input         Update_En;       // 决断阶段确认这是一条分支/跳转指令
    input  [31:0] Update_PC;       // 发生分支指令的 PC
    input  [31:0] Update_Target;   // 算出的真实跳转目标
    input         Update_Taken;    // 真实方向（1为跳，0为不跳）
    input         Mispredict_Real; // 是否发生了误预测（预测方向与真实方向不符）
    
    wire [31:0] next_PC;
    
    always @(posedge clk or posedge rst) begin
        // reset
        if (rst) begin
            PC <= 32'h0000_2000;  //复位后PC的值
        end
        else if (stall)
            PC <= PC;
        else if (PCWrite) begin
            PC <= next_PC;            //修改指令地址
        end
    end
    reg [29:0] btb_tag    [0:15]; // 存储 PC[31:2] 区分不同分支
    reg [31:0] btb_target [0:15]; // 存储跳转目标
    reg        btb_valid  [0:15]; // 该表项是否有效且倾向于跳转
    
    wire [3:0] fetch_idx = PC[5:2];       // 取指阶段查询 BTB 的索引
    wire [3:0] update_idx = Update_PC[5:2]; // 决断阶段更新 BTB 的索引

    // 1. IF 阶段：查表预测 (0拍惩罚的核心)
    // 只要 Tag 匹配且 Valid 为 1，我们就在 IF 阶段直接判定为跳转，并使用缓存的 Target
    wire btb_hit = btb_valid[fetch_idx] && (btb_tag[fetch_idx] == PC[31:2]);
    wire [31:0] Predict_Target_IF = btb_target[fetch_idx];

    // 2. 下一拍 PC 的生成逻辑优先级
    wire [31:0] PC_plus_4 = PC + 32'd4;
    assign next_PC = Mispredict_Real ? NPC :                 // 最高优先级：ID阶段报错，强制使用 NPC 接口传来的正确地址
                     btb_hit         ? Predict_Target_IF :   // 第二优先级：BTB 命中并预测跳转
                                       PC_plus_4;            // 最低优先级：默认顺序执行+4

    // 4. BTB 的更新逻辑 (时序逻辑，避免长组合路径)
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) begin
                btb_valid[i]  <= 1'b0;
                btb_tag[i]    <= 30'b0;
                btb_target[i] <= 32'b0;
            end
        end else if (Update_En) begin
            // 只有真实发生的分支指令才更新 BTB
            btb_tag[update_idx]    <= Update_PC[31:2];
            btb_target[update_idx] <= Update_Target;
            // 一位状态机：如果实际跳了，将其置为有效（预测跳）；如果不跳，将其失效（预测不跳）
            btb_valid[update_idx]  <= Update_Taken; 
        end
    end
endmodule
