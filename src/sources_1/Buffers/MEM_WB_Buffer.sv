`timescale 1ns / 1ps

module MEM_WB_Buffer #(
    parameter DATA_WIDTH = 32,
    parameter NB_REG     = 5,
    parameter NB_PC      = 32
) (
    input  logic                  i_clk,
    input  logic                  i_reset,
    input  logic                  i_enable,
    // data
    input  logic [DATA_WIDTH-1:0] i_alu_result,
    input  logic [DATA_WIDTH-1:0] i_mem_read_data,
    input  logic [    NB_REG-1:0] i_rd,
    input  logic [     NB_PC-1:0] i_pc_plus_4,
    // control
    input  logic                  i_RegWrite,
    input  logic                  i_MemToReg,
    input  logic                  i_Jump,
    input  logic                  i_Halt,
    // outputs (mirror)
    output logic [DATA_WIDTH-1:0] o_alu_result,
    output logic [DATA_WIDTH-1:0] o_mem_read_data,
    output logic [    NB_REG-1:0] o_rd,
    output logic [     NB_PC-1:0] o_pc_plus_4,
    output logic                  o_RegWrite,
    output logic                  o_MemToReg,
    output logic                  o_Jump,
    output logic                  o_Halt
);

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            o_alu_result    <= '0;
            o_mem_read_data <= '0;
            o_rd            <= '0;
            o_pc_plus_4     <= '0;
            o_RegWrite      <= '0;
            o_MemToReg      <= '0;
            o_Jump          <= '0;
            o_Halt          <= '0;
        end else if (i_enable) begin
            o_alu_result    <= i_alu_result;
            o_mem_read_data <= i_mem_read_data;
            o_rd            <= i_rd;
            o_pc_plus_4     <= i_pc_plus_4;
            o_RegWrite      <= i_RegWrite;
            o_MemToReg      <= i_MemToReg;
            o_Jump          <= i_Jump;
            o_Halt          <= i_Halt;
        end
    end

endmodule
