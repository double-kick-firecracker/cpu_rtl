`timescale 1ns / 1ps

`include "ctrl_signal_def.v"

module MUX_3to1_LMD(X, Y, Z, control, out);
    input  [31:0] X;
    input  [31:0] Y;
    input  [31:0] Z;
    input  [1:0]  control;
    output reg [31:0] out;

    always @(*) begin
        case (control)
            `WDSel_FromALU: out = X;
            `WDSel_FromMEM: out = Y;
            `WDSel_FromPC : out = Z;
            default       : out = 32'b0;
        endcase
    end
endmodule
