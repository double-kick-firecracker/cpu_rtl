`include "ctrl_signal_def.v"
module EXT(imm_in, ExtSel, imm_out,FlushE,ex_imm32,Offset20,Offset,ex_Offset20,ex_Offset,
            clk,rst);    //搞了半天其实只拓展了itype
    input  [11:0]  imm_in;    // 输入的12位立即数
    input          ExtSel,FlushE,clk,rst;    // 扩展选择控制信号
    output reg [31:0] imm_out; // 输出的32位扩展后立即数
    output [31:0] ex_imm32;
    input  [19:0] Offset20;
    input  [11:0] Offset;
    output reg [19:0] ex_Offset20;
    output reg [11:0] ex_Offset;
    
    always @(imm_in or ExtSel) begin
        case(ExtSel)
            `ExtSel_ZERO:   imm_out = {20'b0, imm_in[11:0]};        // 零扩展为32位
            `ExtSel_SIGNED: imm_out = {{20{imm_in[11]}}, imm_in[11:0]};  // 符号扩展为32位
            default:        imm_out = 32'b0;                       // 默认输出0
        endcase
    end
    
     Flopr U_IDEX_IMM  ( .clk(clk), .rst(rst), .in_data(imm_out),.out_data(ex_imm32) ,.CLR(FlushE), .Stall(1'b0));
     
     always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_Offset20 <= 0;
            ex_Offset   <= 0;
        end    
        else begin
            ex_Offset20 <= Offset20;
            ex_Offset   <= Offset;
        end
    end
endmodule