`timescale 1ns / 1ps

module EX_MEM_Buffer #(
    parameter DATA_WIDTH = 32,
    parameter NB_REG     = 5,
    parameter NB_PC      = 32
) (
    input  logic                  i_clk,
    input  logic                  i_reset,
    input  logic                  i_enable,
    input  logic                  i_flush,
    // data
    input  logic [DATA_WIDTH-1:0] i_alu_result,
    input  logic                  i_zero,
    input  logic [DATA_WIDTH-1:0] i_read_data_2,
    input  logic [    NB_REG-1:0] i_rd,
    input  logic [           2:0] i_funct3,
    input  logic [     NB_PC-1:0] i_branch_target,
    input  logic [     NB_PC-1:0] i_pc_plus_4,
    // control
    input  logic                  i_RegWrite,
    input  logic                  i_MemRead,
    input  logic                  i_MemWrite,
    input  logic                  i_MemToReg,
    input  logic                  i_Branch,
    input  logic                  i_Jump,
    input  logic                  i_JumpReg,
    input  logic                  i_Halt,
    // outputs (mirror)
    output logic [DATA_WIDTH-1:0] o_alu_result,
    output logic                  o_zero,
    output logic [DATA_WIDTH-1:0] o_read_data_2,
    output logic [    NB_REG-1:0] o_rd,
    output logic [           2:0] o_funct3,
    output logic [     NB_PC-1:0] o_branch_target,
    output logic [     NB_PC-1:0] o_pc_plus_4,
    output logic                  o_RegWrite,
    output logic                  o_MemRead,
    output logic                  o_MemWrite,
    output logic                  o_MemToReg,
    output logic                  o_Branch,
    output logic                  o_Jump,
    output logic                  o_JumpReg,
    output logic                  o_Halt
);

    always_ff @(posedge i_clk) begin
        if (i_reset || i_flush) begin
            o_alu_result    <= '0;
            o_zero          <= '0;
            o_read_data_2   <= '0;
            o_rd            <= '0;
            o_funct3        <= '0;
            o_branch_target <= '0;
            o_pc_plus_4     <= '0;
            o_RegWrite      <= '0;
            o_MemRead       <= '0;
            o_MemWrite      <= '0;
            o_MemToReg      <= '0;
            o_Branch        <= '0;
            o_Jump          <= '0;
            o_JumpReg       <= '0;
            o_Halt          <= '0;
        end else if (i_enable) begin
            o_alu_result    <= i_alu_result;
            o_zero          <= i_zero;
            o_read_data_2   <= i_read_data_2;
            o_rd            <= i_rd;
            o_funct3        <= i_funct3;
            o_branch_target <= i_branch_target;
            o_pc_plus_4     <= i_pc_plus_4;
            o_RegWrite      <= i_RegWrite;
            o_MemRead       <= i_MemRead;
            o_MemWrite      <= i_MemWrite;
            o_MemToReg      <= i_MemToReg;
            o_Branch        <= i_Branch;
            o_Jump          <= i_Jump;
            o_JumpReg       <= i_JumpReg;
            o_Halt          <= i_Halt;
        end
    end

endmodule
