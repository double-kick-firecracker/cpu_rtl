`timescale 1ns / 1ps
`include "ctrl_signal_def.v"
`include "instruction_def.v"

module ALU(A,B,ALUOp,zero,ALU_result);
    input signed [31:0] A;
    input signed [31:0] B;
    input [3:0] ALUOp;
    output zero;
    output reg signed [31:0] ALU_result;

endmodule
