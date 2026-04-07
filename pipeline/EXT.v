`include "ctrl_signal_def.v"
module EXT(imm_in, ExtSel, imm_out);
    input  [11:0]  imm_in;    // 输入的12位立即数
    input          ExtSel;    // 扩展选择控制信号
    output reg [31:0] imm_out; // 输出的32位扩展后立即数

    always @(imm_in or ExtSel) begin
        case(ExtSel)
            `ExtSel_ZERO:   imm_out = {20'b0, imm_in[11:0]};        // 零扩展为32位
            `ExtSel_SIGNED: imm_out = {{20{imm_in[11]}}, imm_in[11:0]};  // 符号扩展为32位
            default:        imm_out = 32'b0;                       // 默认输出0
        endcase
    end
endmodule