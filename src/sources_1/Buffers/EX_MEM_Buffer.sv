`timescale 1ns / 1ps

module EX_MEM_Buffer #(
    parameter DATA_WIDTH = 32,
    parameter NB_REG     = 5
) (
    input  logic                  i_clk,
    input  logic                  i_reset,
    input  logic                  i_enable,
    // data
    input  logic [DATA_WIDTH-1:0] i_alu_result,
    input  logic                  i_zero,
    input  logic [DATA_WIDTH-1:0] i_read_data_2,
    input  logic [    NB_REG-1:0] i_rd,
    input  logic [           2:0] i_funct3,
    // control
    input  logic                  i_RegWrite,
    input  logic                  i_MemRead,
    input  logic                  i_MemWrite,
    input  logic                  i_MemToReg,
    input  logic                  i_Branch,
    input  logic                  i_Jump,
    // outputs (mirror)
    output logic [DATA_WIDTH-1:0] o_alu_result,
    output logic                  o_zero,
    output logic [DATA_WIDTH-1:0] o_read_data_2,
    output logic [    NB_REG-1:0] o_rd,
    output logic [           2:0] o_funct3,
    output logic                  o_RegWrite,
    output logic                  o_MemRead,
    output logic                  o_MemWrite,
    output logic                  o_MemToReg,
    output logic                  o_Branch,
    output logic                  o_Jump
);

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            o_alu_result  <= '0;
            o_zero        <= '0;
            o_read_data_2 <= '0;
            o_rd          <= '0;
            o_funct3      <= '0;
            o_RegWrite    <= '0;
            o_MemRead     <= '0;
            o_MemWrite    <= '0;
            o_MemToReg    <= '0;
            o_Branch      <= '0;
            o_Jump        <= '0;
        end else if (i_enable) begin
            o_alu_result  <= i_alu_result;
            o_zero        <= i_zero;
            o_read_data_2 <= i_read_data_2;
            o_rd          <= i_rd;
            o_funct3      <= i_funct3;
            o_RegWrite    <= i_RegWrite;
            o_MemRead     <= i_MemRead;
            o_MemWrite    <= i_MemWrite;
            o_MemToReg    <= i_MemToReg;
            o_Branch      <= i_Branch;
            o_Jump        <= i_Jump;
        end
    end

endmodule
