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

endmodule
