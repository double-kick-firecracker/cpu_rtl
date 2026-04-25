`timescale 1ns / 1ps
`include "ctrl_signal_def.v"
`include "instruction_def.v"

module ALU(A,B,ALUOp,zero,ALU_result,ex_RD2,mem_RD2);
    input signed [31:0] A;
    input signed [31:0] B;
    input [3:0] ALUOp;
    input [31:0] ex_RD2;
    output zero;
    output reg signed [31:0] ALU_result;
    output [31:0] mem_RD2;
    
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
    
    Flopr U_EX_MEM_RD2  ( .clk(clk), .rst(rst), .in_data(ex_RD2), .out_data(mem_RD2),.CLR(1'b0), .Stall(1'b0) );
endmodule
