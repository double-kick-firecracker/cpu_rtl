`timescale 1ns / 1ps

`include "instruction_def.v"
`include "ctrl_signal_def.v"

module pipeline_decode(
    input  [31:0] instr,
    output [4:0]  rs1,
    output [4:0]  rs2,
    output [4:0]  rd,
    output reg [31:0] imm,
    output reg [3:0]  alu_op,
    output reg [1:0]  wb_sel,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        branch,
    output reg        branch_ne,
    output reg        jal,
    output reg        alu_src_imm,
    output reg        use_rs1,
    output reg        use_rs2
);
    localparam [1:0]
        WBSEL_ALU = 2'b00,
        WBSEL_MEM = 2'b01,
        WBSEL_PC4 = 2'b10;

    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;

    wire [31:0] imm_i_signed;
    wire [31:0] imm_i_zero;
    wire [31:0] imm_s;
    wire [31:0] imm_b;
    wire [31:0] imm_j;

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign rd     = instr[11:7];

    assign imm_i_signed = {{20{instr[31]}}, instr[31:20]};
    assign imm_i_zero   = {20'b0, instr[31:20]};
    assign imm_s        = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign imm_b        = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_j        = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    always @(*) begin
        imm         = 32'b0;
        alu_op      = `ALUOp_ADD;
        wb_sel      = WBSEL_ALU;
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        branch      = 1'b0;
        branch_ne   = 1'b0;
        jal         = 1'b0;
        alu_src_imm = 1'b0;
        use_rs1     = 1'b0;
        use_rs2     = 1'b0;

        case (opcode)
            `INSTR_RTYPE_OP: begin
                reg_write = 1'b1;
                use_rs1   = 1'b1;
                use_rs2   = 1'b1;
                case ({funct7, funct3})
                    `INSTR_ADD_FUNCT: alu_op = `ALUOp_ADD;
                    `INSTR_SUB_FUNCT: alu_op = `ALUOp_SUB;
                    `INSTR_AND_FUNCT: alu_op = `ALUOp_AND;
                    `INSTR_OR_FUNCT : alu_op = `ALUOp_OR;
                    `INSTR_XOR_FUNCT: alu_op = `ALUOp_XOR;
                    `INSTR_SLL_FUNCT: alu_op = `ALUOp_SLL;
                    `INSTR_SRL_FUNCT: alu_op = `ALUOp_SRL;
                    `INSTR_SRA_FUNCT: alu_op = `ALUOp_SRA;
                    default: begin
                        reg_write = 1'b0;
                        use_rs1   = 1'b0;
                        use_rs2   = 1'b0;
                    end
                endcase
            end

            `INSTR_ITYPE_OP: begin
                reg_write   = 1'b1;
                use_rs1     = 1'b1;
                alu_src_imm = 1'b1;
                case (funct3)
                    `INSTR_ADDI_FUNCT: begin
                        alu_op = `ALUOp_ADD;
                        imm    = imm_i_signed;
                    end
                    `INSTR_ORI_FUNCT: begin
                        alu_op = `ALUOp_OR;
                        imm    = imm_i_zero;
                    end
                    default: begin
                        reg_write   = 1'b0;
                        use_rs1     = 1'b0;
                        alu_src_imm = 1'b0;
                    end
                endcase
            end

            `INSTR_LW_OP: begin
                reg_write   = 1'b1;
                mem_read    = 1'b1;
                wb_sel      = WBSEL_MEM;
                alu_op      = `ALUOp_ADD;
                alu_src_imm = 1'b1;
                use_rs1     = 1'b1;
                imm         = imm_i_signed;
            end

            `INSTR_SW_OP: begin
                mem_write   = 1'b1;
                alu_op      = `ALUOp_ADD;
                alu_src_imm = 1'b1;
                use_rs1     = 1'b1;
                use_rs2     = 1'b1;
                imm         = imm_s;
            end

            `INSTR_BTYPE_OP: begin
                branch    = 1'b1;
                use_rs1   = 1'b1;
                use_rs2   = 1'b1;
                alu_op    = `ALUOp_SUB;
                imm       = imm_b;
                branch_ne = (funct3 == `INSTR_BNE_FUNCT);
                if ((funct3 != `INSTR_BEQ_FUNCT) && (funct3 != `INSTR_BNE_FUNCT)) begin
                    branch  = 1'b0;
                    use_rs1 = 1'b0;
                    use_rs2 = 1'b0;
                end
            end

            `INSTR_JAL_OP: begin
                reg_write = 1'b1;
                jal       = 1'b1;
                wb_sel    = WBSEL_PC4;
                imm       = imm_j;
            end
        endcase
    end
endmodule
