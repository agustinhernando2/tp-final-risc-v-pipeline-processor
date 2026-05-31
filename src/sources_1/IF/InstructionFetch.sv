`timescale 1ns / 1ps

module InstructionFetch #(
    parameter NB_PC   = 32,
    parameter NB_INST = 32,
    parameter NB_ADDR = 8
) (
    input logic               i_clk,
    input logic               i_reset,
    input logic               i_enable,
    input logic               i_PCSrc,
    input logic [  NB_PC-1:0] i_PCBranch,
    input logic               i_mem_wr,
    input logic [NB_ADDR-1:0] i_mem_addr,
    input logic [NB_INST-1:0] i_mem_data,

    output logic [  NB_PC-1:0] o_PC_increment,
    output logic [NB_INST-1:0] o_instruction,
    output logic [  NB_PC-1:0] o_PC
);

    logic [NB_PC-1:0] w_PC;
    logic [NB_PC-1:0] w_muxPC;

    PosEdgeRegister #(
        .DATA_WIDTH (NB_PC),
        .RESET_VALUE(0)
    ) PC (
        .i_clk   (i_clk),
        .i_reset (i_reset),
        .i_enable(i_enable),
        .i_data  (w_muxPC),
        .o_data  (w_PC)
    );

    Adder #(
        .DATA_WIDTH(NB_PC)
    ) u_PC_increment (
        .i_operand_a(w_PC),
        .i_operand_b(NB_PC'(1)),
        .o_sum      (o_PC_increment)
    );

    InstructionMemory #(
        .NB_PC  (NB_PC),
        .NB_INST(NB_INST),
        .NB_ADDR(NB_ADDR)
    ) u_InstructionMemory (
        .i_clk        (i_clk),
        .i_reset      (i_reset),
        .i_PC         (w_PC),
        .i_mem_wr     (i_mem_wr),
        .i_mem_addr   (i_mem_addr),
        .i_mem_data   (i_mem_data),
        .o_instruction(o_instruction)
    );

    mux1_2 #(
        .DATA_WIDTH(NB_PC)
    ) u_muxPC (
        .i_a  (o_PC_increment),
        .i_b  (i_PCBranch),
        .i_sel(i_PCSrc),
        .o_out(w_muxPC)
    );

    assign o_PC = w_PC;

endmodule
