`timescale 1ns / 1ps

module MEM_WB_Buffer #(
    parameter DATA_WIDTH = 32,
    parameter NB_REG     = 5
) (
    input  logic                  i_clk,
    input  logic                  i_reset,
    input  logic                  i_enable,
    // data
    input  logic [DATA_WIDTH-1:0] i_alu_result,
    input  logic [DATA_WIDTH-1:0] i_mem_read_data,
    input  logic [    NB_REG-1:0] i_rd,
    // control
    input  logic                  i_RegWrite,
    input  logic                  i_MemToReg,
    // outputs (mirror)
    output logic [DATA_WIDTH-1:0] o_alu_result,
    output logic [DATA_WIDTH-1:0] o_mem_read_data,
    output logic [    NB_REG-1:0] o_rd,
    output logic                  o_RegWrite,
    output logic                  o_MemToReg
);

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            o_alu_result    <= '0;
            o_mem_read_data <= '0;
            o_rd            <= '0;
            o_RegWrite      <= '0;
            o_MemToReg      <= '0;
        end else if (i_enable) begin
            o_alu_result    <= i_alu_result;
            o_mem_read_data <= i_mem_read_data;
            o_rd            <= i_rd;
            o_RegWrite      <= i_RegWrite;
            o_MemToReg      <= i_MemToReg;
        end
    end

endmodule
