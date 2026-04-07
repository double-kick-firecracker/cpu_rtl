`timescale 1ns / 1ps

`include "ctrl_signal_def.v"
`include "instruction_def.v"

module ControlUnit(
    input rst,          //
    input clk,          //
    input zero,         //
    input [6:0] opcode, //
    input [6:0] Funct7, //
    input [2:0] Funct3, //
    output reg PCWrite, //
    output reg InsMemRW,//
    output reg IRWrite, //
    output reg RFWrite, //
    output reg DMCtrl,  //
    output reg ExtSel,  //
    output reg ALUSrcA, //
    output reg [1:0] ALUSrcB,
    output reg [1:0] RegSel,
    output reg [1:0] NPCOp,
    output reg [1:0] WDSel,
    output reg [3:0] ALUOp
);

    // The controller is the "brain" of the CPU.
    // It tells every module what to do in each cycle.
    // Because this project has IR/A/B/ALUOut registers, it is natural
    // to implement the controller as a small finite state machine.

    localparam [3:0]
        S_FETCH       = 4'd0,
        S_DECODE      = 4'd1,
        S_EXE_R       = 4'd2,
        S_EXE_I       = 4'd3,
        S_MEM_ADDR    = 4'd4,
        S_MEM_READ    = 4'd5,
        S_MEM_WB      = 4'd6,
        S_MEM_WRITE   = 4'd7,
        S_BRANCH      = 4'd8,
        S_JAL         = 4'd9,
        S_WB_ALU      = 4'd10,
        S_UNSUPPORTED = 4'd11;

    reg [3:0] state;
    reg [3:0] next_state;

    wire [9:0] rtype_funct;
    wire rtype_supported;
    wire itype_supported;
    wire btype_supported;

    // R-type instructions are identified by the combination {Funct7, Funct3}.
    assign rtype_funct = {Funct7, Funct3};

    assign rtype_supported =
        (rtype_funct == `INSTR_ADD_FUNCT) ||
        (rtype_funct == `INSTR_SUB_FUNCT) ||
        (rtype_funct == `INSTR_AND_FUNCT) ||
        (rtype_funct == `INSTR_OR_FUNCT)  ||
        (rtype_funct == `INSTR_XOR_FUNCT) ||
        (rtype_funct == `INSTR_SLL_FUNCT) ||
        (rtype_funct == `INSTR_SRL_FUNCT) ||
        (rtype_funct == `INSTR_SRA_FUNCT);

    assign itype_supported =
        (Funct3 == `INSTR_ADDI_FUNCT) ||
        (Funct3 == `INSTR_ORI_FUNCT);

    assign btype_supported =
        (Funct3 == `INSTR_BEQ_FUNCT) ||
        (Funct3 == `INSTR_BNE_FUNCT);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_FETCH;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            S_FETCH: begin
                next_state = S_DECODE;
            end

            S_DECODE: begin
                // Decode decides which path the current instruction should follow.
                case (opcode)
                    `INSTR_RTYPE_OP: next_state = rtype_supported ? S_EXE_R : S_UNSUPPORTED;
                    `INSTR_ITYPE_OP: next_state = itype_supported ? S_EXE_I : S_UNSUPPORTED;
                    `INSTR_LW_OP   : next_state = S_MEM_ADDR;
                    `INSTR_SW_OP   : next_state = S_MEM_ADDR;
                    `INSTR_BTYPE_OP: next_state = btype_supported ? S_BRANCH : S_UNSUPPORTED;
                    `INSTR_JAL_OP  : next_state = S_JAL;
                    default        : next_state = S_UNSUPPORTED;
                endcase
            end

            S_EXE_R      : next_state = S_WB_ALU;
            S_EXE_I      : next_state = S_WB_ALU;
            S_MEM_ADDR   : next_state = (opcode == `INSTR_LW_OP) ? S_MEM_READ : S_MEM_WRITE;
            S_MEM_READ   : next_state = S_MEM_WB;
            S_MEM_WB     : next_state = S_FETCH;
            S_MEM_WRITE  : next_state = S_FETCH;
            S_BRANCH     : next_state = S_FETCH;
            S_JAL        : next_state = S_FETCH;
            S_WB_ALU     : next_state = S_FETCH;
            default      : next_state = S_FETCH;
        endcase
    end

    always @(*) begin
        // Default values first.
        // Then each state only overrides the signals it really needs.
        PCWrite  = 1'b0;
        InsMemRW = 1'b0;
        IRWrite  = 1'b0;
        RFWrite  = 1'b0;
        DMCtrl   = `DMCtrl_RD;
        ExtSel   = `ExtSel_SIGNED;
        ALUSrcA  = `ALUSrcA_A;
        ALUSrcB  = `ALUSrcB_B;
        RegSel   = `RegSel_rd;
        NPCOp    = `NPC_PC;
        WDSel    = `WDSel_FromALU;
        ALUOp    = `ALUOp_ADD;

        case (state)
            S_FETCH: begin
                // Read instruction memory and store the instruction in IR.
                // PC is updated later, in the final state of each instruction.
                InsMemRW = 1'b1;
                IRWrite  = 1'b1;
            end

            S_EXE_R: begin
                // Select the right ALU operation for the current R-type instruction.
                case (rtype_funct)
                    `INSTR_ADD_FUNCT: ALUOp = `ALUOp_ADD;
                    `INSTR_SUB_FUNCT: ALUOp = `ALUOp_SUB;
                    `INSTR_AND_FUNCT: ALUOp = `ALUOp_AND;
                    `INSTR_OR_FUNCT : ALUOp = `ALUOp_OR;
                    `INSTR_XOR_FUNCT: ALUOp = `ALUOp_XOR;
                    `INSTR_SLL_FUNCT: ALUOp = `ALUOp_SLL;
                    `INSTR_SRL_FUNCT: ALUOp = `ALUOp_SRL;
                    `INSTR_SRA_FUNCT: ALUOp = `ALUOp_SRA;
                    default         : ALUOp = `ALUOp_ADD;
                endcase
            end

            S_EXE_I: begin
                // I-type instructions use an immediate as ALU operand B.
                ALUSrcB = `ALUSrcB_Imm;
                case (Funct3)
                    `INSTR_ADDI_FUNCT: begin
                        ExtSel = `ExtSel_SIGNED;
                        ALUOp  = `ALUOp_ADD;
                    end
                    `INSTR_ORI_FUNCT: begin
                        ExtSel = `ExtSel_ZERO;
                        ALUOp  = `ALUOp_OR;
                    end
                    default: begin
                        ExtSel = `ExtSel_SIGNED;
                        ALUOp  = `ALUOp_ADD;
                    end
                endcase
            end

            S_MEM_ADDR: begin
                // Compute the effective address for lw/sw.
                ALUOp = `ALUOp_ADD;
                if (opcode == `INSTR_SW_OP) begin
                    ALUSrcB = `ALUSrcB_Offset;
                end
                else begin
                    ALUSrcB = `ALUSrcB_Imm;
                    ExtSel  = `ExtSel_SIGNED;
                end
            end

            S_MEM_READ: begin
                // DM reads when DMCtrl = RD.
                DMCtrl = `DMCtrl_RD;
            end

            S_MEM_WB: begin
                // Write memory data back to the register file, then move to next instruction.
                RFWrite = 1'b1;
                WDSel   = `WDSel_FromMEM;
                PCWrite = 1'b1;
                NPCOp   = `NPC_PC;
            end

            S_MEM_WRITE: begin
                // Store one word to data memory, then continue.
                DMCtrl  = `DMCtrl_WR;
                PCWrite = 1'b1;
                NPCOp   = `NPC_PC;
            end

            S_BRANCH: begin
                // Compare two source registers and choose the next PC.
                ALUOp   = `ALUOp_SUB;
                PCWrite = 1'b1;

                if (Funct3 == `INSTR_BEQ_FUNCT) begin
                    NPCOp = zero ? `NPC_Offset12 : `NPC_PC;
                end
                else begin
                    NPCOp = zero ? `NPC_PC : `NPC_Offset12;
                end
            end

            S_JAL: begin
                // jal writes PC + 4 to rd and jumps to PC + offset20.
                RFWrite = 1'b1;
                WDSel   = `WDSel_FromPC;
                PCWrite = 1'b1;
                NPCOp   = `NPC_Offset20;
            end

            S_WB_ALU: begin
                // Regular ALU write-back.
                RFWrite = 1'b1;
                WDSel   = `WDSel_FromALU;
                PCWrite = 1'b1;
                NPCOp   = `NPC_PC;
            end

            S_UNSUPPORTED: begin
                // If an instruction is not supported in this teaching project,
                // skip it instead of hanging forever.
                PCWrite = 1'b1;
                NPCOp   = `NPC_PC;
            end
        endcase
    end

endmodule
