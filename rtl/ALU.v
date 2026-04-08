`timescale 1ns / 1ps
`include "ctrl_signal_def.v"
`include "instruction_def.v"

module ALU(A,B,ALUOp,zero,ALU_result);
    input signed [31:0] A;
    input signed [31:0] B;
    input [3:0] ALUOp;
    output zero;
    output reg signed [31:0] ALU_result;
    
    always @(*)begin
        case(ALUOp)
            `ALUOp_ADD: ALU_result = A + B;
            `ALUOp_SUB: ALU_result = A - B;
            `ALUOp_AND: ALU_result = A & B;
            `ALUOp_OR : ALU_result = A | B;
            `ALUOp_XOR: ALU_result = A ^ B;
            `ALUOp_SRA: ALU_result = A >>> B[4:0]; 
            `ALUOp_SLL: ALU_result = A << B[4:0];
            `ALUOp_SRL: ALU_result = $signed($unsigned(A) >> B[4:0]); //因为把alu_result设置成了signed
            default   : ALU_result = 32'sd0;
        endcase
    end
    
    assign zero = (ALU_result == 32'sd0);
endmodule
