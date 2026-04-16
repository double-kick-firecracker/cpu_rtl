`timescale 1ns / 1ps

module pipeline_forward_unit(
    input  [4:0] ex_rs1,
    input  [4:0] ex_rs2,
    input  [4:0] ex_mem_rd,
    input  [4:0] mem_wb_rd,
    input        ex_mem_reg_write,
    input        mem_wb_reg_write,
    input  [1:0] ex_mem_wb_sel,
    output reg [1:0] forward_a_sel,
    output reg [1:0] forward_b_sel
);
    localparam [1:0]
        FWD_NONE  = 2'b00,
        FWD_MEMWB = 2'b01,
        FWD_EXMEM = 2'b10;

    localparam [1:0] WBSEL_MEM = 2'b01;

    always @(*) begin
        forward_a_sel = FWD_NONE;
        forward_b_sel = FWD_NONE;

        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_wb_sel != WBSEL_MEM) && (ex_mem_rd == ex_rs1)) begin
            forward_a_sel = FWD_EXMEM;
        end
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == ex_rs1)) begin
            forward_a_sel = FWD_MEMWB;
        end

        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_wb_sel != WBSEL_MEM) && (ex_mem_rd == ex_rs2)) begin
            forward_b_sel = FWD_EXMEM;
        end
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == ex_rs2)) begin
            forward_b_sel = FWD_MEMWB;
        end
    end
endmodule
