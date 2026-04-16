`timescale 1ns / 1ps

module pipeline_hazard_unit(
    input  [4:0] id_rs1,
    input  [4:0] id_rs2,
    input  [4:0] ex_rd,
    input        id_use_rs1,
    input        id_use_rs2,
    input        ex_mem_read,
    input        ex_control_taken,
    output reg   pc_write,
    output reg   if_id_write,
    output reg   if_id_flush,
    output reg   id_ex_flush,
    output reg   load_use_stall
);
    always @(*) begin
        pc_write       = 1'b1;
        if_id_write    = 1'b1;
        if_id_flush    = 1'b0;
        id_ex_flush    = 1'b0;
        load_use_stall = 1'b0;

        if (ex_mem_read &&
            (ex_rd != 5'd0) &&
            ((id_use_rs1 && (ex_rd == id_rs1)) ||
             (id_use_rs2 && (ex_rd == id_rs2)))) begin
            load_use_stall = 1'b1;
        end

        if (ex_control_taken) begin
            if_id_flush = 1'b1;
            id_ex_flush = 1'b1;
        end
        else if (load_use_stall) begin
            pc_write    = 1'b0;
            if_id_write = 1'b0;
            id_ex_flush = 1'b1;
        end
    end
endmodule
