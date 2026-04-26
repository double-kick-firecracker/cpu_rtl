`include "ctrl_signal_def.v"
module MUX_3to1(X, Y, Z, control, out,wb_rd);
    input  [4:0]  X,wb_rd;        //rd
    input  [4:0]  Y;        //预留输入
    input  [4:0]  Z;        //预留输入
    input  [1:0]  control;  //选择控制信号
    output reg [4:0] out;   //输出选择结果

    always @ (wb_rd or Y or Z or control) begin
        case(control)
            `RegSel_rd  : out = wb_rd;  //选择X
            `RegSel_rt  : out = Y;  //选择Y——MIPS残留
            `RegSel_31  : out = Z;  //选择Z
            `RegSel_else: out = 0;
            default     : out = 0;
        endcase
    end
endmodule