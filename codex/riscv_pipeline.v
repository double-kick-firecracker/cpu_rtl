`timescale 1ns / 1ps

`include "instruction_def.v"
`include "ctrl_signal_def.v"

module riscv_pipeline(
    input clk,
    input rst
);
    localparam [1:0]
        WBSEL_ALU = 2'b00,
        WBSEL_MEM = 2'b01,
        WBSEL_PC4 = 2'b10;

    localparam [31:0] NOP = 32'h0000_0013;

    reg [31:0] PC;

    wire [31:0] if_instr;
    wire [31:0] if_pc4;

    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;

    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_pc4;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg [3:0]  id_ex_alu_op;
    reg [1:0]  id_ex_wb_sel;
    reg        id_ex_reg_write;
    reg        id_ex_mem_read;
    reg        id_ex_mem_write;
    reg        id_ex_branch;
    reg        id_ex_branch_ne;
    reg        id_ex_jal;
    reg        id_ex_alu_src_imm;

    reg [31:0] ex_mem_pc4;
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_store_data;
    reg [4:0]  ex_mem_rd;
    reg [1:0]  ex_mem_wb_sel;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;

    reg [31:0] mem_wb_pc4;
    reg [31:0] mem_wb_alu_result;
    reg [31:0] mem_wb_mem_data;
    reg [4:0]  mem_wb_rd;
    reg [1:0]  mem_wb_wb_sel;
    reg        mem_wb_reg_write;

    wire [4:0] id_rs1;
    wire [4:0] id_rs2;
    wire [4:0] id_rd;
    wire [31:0] id_rd1;
    wire [31:0] id_rd2;

    reg [31:0] dec_imm;
    reg [3:0]  dec_alu_op;
    reg [1:0]  dec_wb_sel;
    reg        dec_reg_write;
    reg        dec_mem_read;
    reg        dec_mem_write;
    reg        dec_branch;
    reg        dec_branch_ne;
    reg        dec_jal;
    reg        dec_alu_src_imm;
    reg        dec_use_rs1;
    reg        dec_use_rs2;

    wire       pc_write;
    wire       if_id_write;
    wire       if_id_flush;
    wire       id_ex_flush;
    wire       load_use_stall;

    wire [1:0]  forward_a_sel;
    wire [1:0]  forward_b_sel;
    wire [31:0] ex_forward_a;
    wire [31:0] ex_forward_b;
    wire [31:0] ex_alu_b;
    wire [31:0] ex_alu_result;
    wire        ex_zero;
    wire        ex_branch_taken;
    wire        ex_control_taken;
    wire [31:0] ex_target_pc;

    wire [31:0] mem_read_data;
    wire [31:0] wb_data;

    IM_pipeline U_IM (
        .addr(PC[11:2]),
        .Ins(if_instr)
    );

    pipeline_decode U_DECODE (
        .instr(if_id_instr),
        .rs1(id_rs1),
        .rs2(id_rs2),
        .rd(id_rd),
        .imm(dec_imm),
        .alu_op(dec_alu_op),
        .wb_sel(dec_wb_sel),
        .reg_write(dec_reg_write),
        .mem_read(dec_mem_read),
        .mem_write(dec_mem_write),
        .branch(dec_branch),
        .branch_ne(dec_branch_ne),
        .jal(dec_jal),
        .alu_src_imm(dec_alu_src_imm),
        .use_rs1(dec_use_rs1),
        .use_rs2(dec_use_rs2)
    );

    RF_pipeline U_RF (
        .RR1(id_rs1),
        .RR2(id_rs2),
        .WR(mem_wb_rd),
        .WD(wb_data),
        .RFWrite(mem_wb_reg_write),
        .clk(clk),
        .RD1(id_rd1),
        .RD2(id_rd2)
    );

    ALU U_ALU (
        .A(ex_forward_a),
        .B(ex_alu_b),
        .ALUOp(id_ex_alu_op),
        .zero(ex_zero),
        .ALU_result(ex_alu_result)
    );

    DM_pipeline U_DM (
        .Addr(ex_mem_alu_result[11:2]),
        .WD(ex_mem_store_data),
        .clk(clk),
        .MemWrite(ex_mem_mem_write),
        .RD(mem_read_data)
    );

    pipeline_forward_unit U_FORWARD (
        .ex_rs1(id_ex_rs1),
        .ex_rs2(id_ex_rs2),
        .ex_mem_rd(ex_mem_rd),
        .mem_wb_rd(mem_wb_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .mem_wb_reg_write(mem_wb_reg_write),
        .ex_mem_wb_sel(ex_mem_wb_sel),
        .forward_a_sel(forward_a_sel),
        .forward_b_sel(forward_b_sel)
    );

    pipeline_hazard_unit U_HAZARD (
        .id_rs1(id_rs1),
        .id_rs2(id_rs2),
        .ex_rd(id_ex_rd),
        .id_use_rs1(dec_use_rs1),
        .id_use_rs2(dec_use_rs2),
        .ex_mem_read(id_ex_mem_read),
        .ex_control_taken(ex_control_taken),
        .pc_write(pc_write),
        .if_id_write(if_id_write),
        .if_id_flush(if_id_flush),
        .id_ex_flush(id_ex_flush),
        .load_use_stall(load_use_stall)
    );

    assign if_pc4   = PC + 32'd4;
    assign wb_data = (mem_wb_wb_sel == WBSEL_MEM) ? mem_wb_mem_data :
                     (mem_wb_wb_sel == WBSEL_PC4) ? mem_wb_pc4 :
                                                    mem_wb_alu_result;

    assign ex_forward_a = (forward_a_sel == 2'b10) ? ((ex_mem_wb_sel == WBSEL_PC4) ? ex_mem_pc4 : ex_mem_alu_result) :
                          (forward_a_sel == 2'b01) ? wb_data :
                                                     id_ex_rs1_data;

    assign ex_forward_b = (forward_b_sel == 2'b10) ? ((ex_mem_wb_sel == WBSEL_PC4) ? ex_mem_pc4 : ex_mem_alu_result) :
                          (forward_b_sel == 2'b01) ? wb_data :
                                                     id_ex_rs2_data;

    assign ex_alu_b        = id_ex_alu_src_imm ? id_ex_imm : ex_forward_b;
    assign ex_branch_taken = id_ex_branch && (id_ex_branch_ne ? !ex_zero : ex_zero);
    assign ex_control_taken = id_ex_jal || ex_branch_taken;
    assign ex_target_pc    = id_ex_pc + id_ex_imm;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC        <= 32'h0000_2000;
            if_id_pc  <= 32'b0;
            if_id_instr <= NOP;
        end
        else begin
            if (pc_write) begin
                PC <= ex_control_taken ? ex_target_pc : if_pc4;
            end

            if (if_id_flush) begin
                if_id_pc    <= 32'b0;
                if_id_instr <= NOP;
            end
            else if (if_id_write) begin
                if_id_pc    <= PC;
                if_id_instr <= if_instr;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_ex_pc          <= 32'b0;
            id_ex_pc4         <= 32'b0;
            id_ex_rs1_data    <= 32'b0;
            id_ex_rs2_data    <= 32'b0;
            id_ex_imm         <= 32'b0;
            id_ex_rs1         <= 5'b0;
            id_ex_rs2         <= 5'b0;
            id_ex_rd          <= 5'b0;
            id_ex_alu_op      <= `ALUOp_ADD;
            id_ex_wb_sel      <= WBSEL_ALU;
            id_ex_reg_write   <= 1'b0;
            id_ex_mem_read    <= 1'b0;
            id_ex_mem_write   <= 1'b0;
            id_ex_branch      <= 1'b0;
            id_ex_branch_ne   <= 1'b0;
            id_ex_jal         <= 1'b0;
            id_ex_alu_src_imm <= 1'b0;
        end
        else if (id_ex_flush) begin
            id_ex_pc          <= 32'b0;
            id_ex_pc4         <= 32'b0;
            id_ex_rs1_data    <= 32'b0;
            id_ex_rs2_data    <= 32'b0;
            id_ex_imm         <= 32'b0;
            id_ex_rs1         <= 5'b0;
            id_ex_rs2         <= 5'b0;
            id_ex_rd          <= 5'b0;
            id_ex_alu_op      <= `ALUOp_ADD;
            id_ex_wb_sel      <= WBSEL_ALU;
            id_ex_reg_write   <= 1'b0;
            id_ex_mem_read    <= 1'b0;
            id_ex_mem_write   <= 1'b0;
            id_ex_branch      <= 1'b0;
            id_ex_branch_ne   <= 1'b0;
            id_ex_jal         <= 1'b0;
            id_ex_alu_src_imm <= 1'b0;
        end
        else begin
            id_ex_pc          <= if_id_pc;
            id_ex_pc4         <= if_id_pc + 32'd4;
            id_ex_rs1_data    <= id_rd1;
            id_ex_rs2_data    <= id_rd2;
            id_ex_imm         <= dec_imm;
            id_ex_rs1         <= id_rs1;
            id_ex_rs2         <= id_rs2;
            id_ex_rd          <= id_rd;
            id_ex_alu_op      <= dec_alu_op;
            id_ex_wb_sel      <= dec_wb_sel;
            id_ex_reg_write   <= dec_reg_write;
            id_ex_mem_read    <= dec_mem_read;
            id_ex_mem_write   <= dec_mem_write;
            id_ex_branch      <= dec_branch;
            id_ex_branch_ne   <= dec_branch_ne;
            id_ex_jal         <= dec_jal;
            id_ex_alu_src_imm <= dec_alu_src_imm;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_mem_pc4        <= 32'b0;
            ex_mem_alu_result <= 32'b0;
            ex_mem_store_data <= 32'b0;
            ex_mem_rd         <= 5'b0;
            ex_mem_wb_sel     <= WBSEL_ALU;
            ex_mem_reg_write  <= 1'b0;
            ex_mem_mem_read   <= 1'b0;
            ex_mem_mem_write  <= 1'b0;
        end
        else begin
            ex_mem_pc4        <= id_ex_pc4;
            ex_mem_alu_result <= ex_alu_result;
            ex_mem_store_data <= ex_forward_b;
            ex_mem_rd         <= id_ex_rd;
            ex_mem_wb_sel     <= id_ex_wb_sel;
            ex_mem_reg_write  <= id_ex_reg_write;
            ex_mem_mem_read   <= id_ex_mem_read;
            ex_mem_mem_write  <= id_ex_mem_write;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_wb_pc4        <= 32'b0;
            mem_wb_alu_result <= 32'b0;
            mem_wb_mem_data   <= 32'b0;
            mem_wb_rd         <= 5'b0;
            mem_wb_wb_sel     <= WBSEL_ALU;
            mem_wb_reg_write  <= 1'b0;
        end
        else begin
            mem_wb_pc4        <= ex_mem_pc4;
            mem_wb_alu_result <= ex_mem_alu_result;
            // Only latch memory data for actual loads.
            // This avoids propagating X values from unrelated memory addresses
            // into the WB stage during non-load instructions.
            mem_wb_mem_data   <= ex_mem_mem_read ? mem_read_data : 32'b0;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_wb_sel     <= ex_mem_wb_sel;
            mem_wb_reg_write  <= ex_mem_reg_write;
        end
    end
endmodule
