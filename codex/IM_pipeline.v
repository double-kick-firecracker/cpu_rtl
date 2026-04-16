`timescale 1ns / 1ps

module IM_pipeline(
    input  [11:2] addr,
    output [31:0] Ins
);
    reg [31:0] memory[0:1023];

    assign Ins = memory[addr];
endmodule
