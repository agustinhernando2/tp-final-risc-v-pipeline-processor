`timescale 1ns / 1ps

module instructionDecode#(
    parameter NB_inst = 32,
    parameter NB_REG = 5,
    parameter DATA_WIDTH = 32,
)(
    input i_clk,
    input i_reset,
    input i_regWrite,
    input [NB_inst-1:0] i_instruction,

    input [NB_REG-1:0] i_read_reg_1,
    input [NB_REG-1:0] i_read_reg_2,

    input [NB_REG-1:0] i_write_reg,         // register number to write
    input [DATA_WIDTH-1:0] i_write_data,    // data to write
    input i_regWrite,

    output [DATA_WIDTH-1:0] o_read_reg_1,
    output [DATA_WIDTH-1:0] o_read_reg_2,
    output [2**NB_REG-1:0] o_extended_immediate
    );


    RegisterFile RF(
        .i_clk(i_clk),
        .i_reset(i_reset),
        .i_read_reg_1(i_read_reg_1),
        .i_read_reg_2(i_read_reg_2),
        .i_write_reg(i_write_reg),
        .i_write_data(i_write_data),
        .i_regWrite(i_regWrite),
        .o_read_reg_1(o_read_reg_1),
        .o_read_reg_2(o_read_reg_2),
    );

    SignExtension SE(
        .i_immediate(i_instruction[NB_inst-1:20]), //imm[11:0]
        .o_extended(o_extended_immediate)
    );

endmodule
