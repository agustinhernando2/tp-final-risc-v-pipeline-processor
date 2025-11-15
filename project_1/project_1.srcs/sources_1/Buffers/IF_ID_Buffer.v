`timescale 1ns / 1ps

module IF_ID_Buffer#(
    parameter NB_PC = 32,
    parameter NB_inst = 32
)(
    input i_clk,
    input i_reset,
    input i_enable,
    input [NB_PC-1:0] i_PC_increment,
    input [NB_inst-1:0] i_instruction,

    output [NB_PC-1:0] o_PC_increment,
    output [NB_inst-1:0] o_instruction
);

    PosEdgeRegister #(
        .DATA_WIDTH(NB_PC),
        .RESET_VALUE(0)
    ) reg_PC_inc (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_enable(i_enable),
        .i_data(i_PC_increment),
        .o_data(o_PC_increment)
    );

    PosEdgeRegister #(
        .DATA_WIDTH(NB_inst),
        .RESET_VALUE(0)
    ) reg_A (
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_enable(i_enable),
        .i_data(i_instruction),
        .o_data(o_instruction)
    );

endmodule

