`timescale 1ns / 1ps

module IF_ID_Buffer #(
    parameter NB_PC   = 32,
    parameter NB_INST = 32
) (
    input  logic               i_clk,
    input  logic               i_reset,
    input  logic               i_enable,
    input  logic               i_flush,
    input  logic [  NB_PC-1:0] i_PC,
    input  logic [  NB_PC-1:0] i_pc_plus_4,
    input  logic [NB_INST-1:0] i_instruction,
    output logic [  NB_PC-1:0] o_PC,
    output logic [  NB_PC-1:0] o_pc_plus_4,
    output logic [NB_INST-1:0] o_instruction
);

    always_ff @(posedge i_clk) begin
        if (i_reset || i_flush) begin
            o_PC          <= '0;
            o_pc_plus_4   <= '0;
            o_instruction <= '0;
        end else if (i_enable) begin
            o_PC          <= i_PC;
            o_pc_plus_4   <= i_pc_plus_4;
            o_instruction <= i_instruction;
        end
    end

endmodule
