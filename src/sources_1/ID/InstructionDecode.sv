`timescale 1ns / 1ps

module instructionDecode #(
    parameter NB_INST    = 32,
    parameter NB_REG     = 5,
    parameter DATA_WIDTH = 32
)(
    input  logic                   i_clk,
    input  logic                   i_reset,
    input  logic [NB_INST-1:0]    i_instruction,
    input  logic [2:0]             i_ImmSrc,       // immediate format, from control unit
    // WB feedback
    input  logic [NB_REG-1:0]     i_write_reg,
    input  logic [DATA_WIDTH-1:0] i_write_data,
    input  logic                   i_regWrite,
    // outputs
    output logic [DATA_WIDTH-1:0] o_read_data_1,
    output logic [DATA_WIDTH-1:0] o_read_data_2,
    output logic [NB_REG-1:0]     o_rd,
    output logic [DATA_WIDTH-1:0] o_immediate
);

    logic [NB_REG-1:0] w_rs1, w_rs2;

    assign w_rs1 = i_instruction[19:15];
    assign w_rs2 = i_instruction[24:20];
    assign o_rd  = i_instruction[11:7];

    RegisterFile #(
        .NB_REG(NB_REG),
        .DATA_WIDTH(DATA_WIDTH)
    ) RF (
        .i_clk        (i_clk),
        .i_reset      (i_reset),
        .i_read_reg_1 (w_rs1),
        .i_read_reg_2 (w_rs2),
        .i_write_reg  (i_write_reg),
        .i_write_data (i_write_data),
        .i_regWrite   (i_regWrite),
        .o_read_reg_1 (o_read_data_1),
        .o_read_reg_2 (o_read_data_2)
    );

    ImmediateExtend #(
        .DATA_WIDTH(DATA_WIDTH)
    ) IMM (
        .i_instruction (i_instruction),
        .i_ImmSrc      (i_ImmSrc),
        .o_immediate   (o_immediate)
    );

endmodule
