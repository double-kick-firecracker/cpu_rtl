`timescale 1ns / 1ps

module DM_pipeline(
    input  [11:2] Addr,
    input  [31:0] WD,
    input         clk,
    input         MemWrite,
    output [31:0] RD
);
    reg [31:0] memory[0:1023];

    assign RD = memory[Addr];

    always @(posedge clk) begin
        if (MemWrite) begin
            memory[Addr] <= WD;
        end
    end
endmodule
