`include "ctrl_signal_def.v"
module MUX_3to1(X, Y, Z, control, out,wb_rd);
    input  [4:0]  X,wb_rd;        //rd
    input  [4:0]  Y;        //预留输入
    input  [4:0]  Z;        //预留输入
    input  [1:0]  control;  //选择控制信号
    output reg [4:0] out;   //输出选择结果

    always @ (*) begin
        out = wb_rd;
    end
endmodule