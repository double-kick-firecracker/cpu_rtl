`timescale 1ns / 1ps
`include "ctrl_signal_def.v"
`include "instruction_def.v"

module ALU(A,B,ALUOp,zero,ALU_result);
    input signed [31:0] A;
    input signed [31:0] B;
    input [3:0] ALUOp;
    output zero;
    output reg signed [31:0] ALU_result;

    // `zero` is used by branch instructions.
    // In this teaching design, beq/bne compare the operands by subtraction.
    // If A - B == 0, the operands are equal.
    assign zero = (ALU_result == 32'sd0);

    always @(*) begin
        case (ALUOp)
            // add/addi/lw/sw all need addition.
            `ALUOp_ADD: ALU_result = A + B;

            // sub and branch comparison use subtraction.
            `ALUOp_SUB: ALU_result = A - B;

            // Basic logic operations.
            `ALUOp_AND: ALU_result = A & B;
            `ALUOp_OR : ALU_result = A | B;
            `ALUOp_XOR: ALU_result = A ^ B;

            // Shift amount only uses the low 5 bits in RV32I.
            `ALUOp_SRA: ALU_result = A >>> B[4:0];
            `ALUOp_SLL: ALU_result = A <<< B[4:0];
            `ALUOp_SRL: ALU_result = $signed($unsigned(A) >> B[4:0]);

            // BR shares the same behavior as subtraction in this project.
            `ALUOp_BR : ALU_result = A - B;
            default   : ALU_result = 32'sd0;
        endcase
    end

endmodule
