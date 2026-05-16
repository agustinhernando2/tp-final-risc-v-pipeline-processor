`timescale 1ns / 1ps

module ExecuteStage #(
    parameter DATA_WIDTH     = 32,
    parameter NB_REG         = 5,
    parameter ALU_CTRL_WIDTH = 4
)(
    input  logic [DATA_WIDTH-1:0] i_read_data_1,
    input  logic [DATA_WIDTH-1:0] i_read_data_2,
    input  logic [DATA_WIDTH-1:0] i_immediate,
    input  logic [NB_REG-1:0]     i_rd,
    input  logic [2:0]            i_funct3,
    input  logic                  i_funct7_5,
    input  logic                  i_ALUSrc,
    input  logic [1:0]            i_ALUOp,
    output logic [DATA_WIDTH-1:0] o_alu_result,
    output logic                  o_zero,
    output logic [DATA_WIDTH-1:0] o_read_data_2,
    output logic [NB_REG-1:0]     o_rd
);

    logic [DATA_WIDTH-1:0]     w_alu_b;
    logic [ALU_CTRL_WIDTH-1:0] w_alu_ctrl;

    mux1_2 #(.DATA_WIDTH(DATA_WIDTH)) u_mux_alu_b (
        .i_a  (i_read_data_2),
        .i_b  (i_immediate),
        .i_sel(i_ALUSrc),
        .o_out(w_alu_b)
    );

    ALUControl #(.ALU_CTRL_WIDTH(ALU_CTRL_WIDTH)) u_alu_control (
        .i_ALUOp    (i_ALUOp),
        .i_funct3   (i_funct3),
        .i_funct7_5 (i_funct7_5),
        .o_ALUCtrl  (w_alu_ctrl)
    );

    ALU #(.DATA_WIDTH(DATA_WIDTH), .ALU_CTRL_WIDTH(ALU_CTRL_WIDTH)) u_alu (
        .i_operand_a (i_read_data_1),
        .i_operand_b (w_alu_b),
        .i_ALUCtrl   (w_alu_ctrl),
        .o_result    (o_alu_result),
        .o_zero      (o_zero)
    );

    assign o_read_data_2 = i_read_data_2;
    assign o_rd          = i_rd;

endmodule
