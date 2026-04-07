`timescale 1ns / 1ps

module RF_pipeline(
    input  [4:0]  RR1,
    input  [4:0]  RR2,
    input  [4:0]  WR,
    input  [31:0] WD,
    input         RFWrite,
    input         clk,
    output [31:0] RD1,
    output [31:0] RD2
);
    reg [31:0] register [0:31];
    integer i;

    always @(posedge clk) begin
        if (RFWrite && (WR != 5'd0)) begin
            register[WR] <= WD;
        end
        register[0] <= 32'b0;
    end

    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            register[i] = 32'b0;
        end
    end

    // Write-through bypass:
    // when the WB stage writes a register in the current cycle,
    // the ID stage can see the new value immediately.
    assign RD1 = (RR1 == 5'd0) ? 32'b0 :
                 ((RFWrite && (WR != 5'd0) && (WR == RR1)) ? WD : register[RR1]);
    assign RD2 = (RR2 == 5'd0) ? 32'b0 :
                 ((RFWrite && (WR != 5'd0) && (WR == RR2)) ? WD : register[RR2]);
endmodule
