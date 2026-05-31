`timescale 1ns / 1ps

module WriteBackStage #(
    parameter DATA_WIDTH = 32,
    parameter NB_REG     = 5,
    parameter NB_PC      = 32
) (
    input  logic [DATA_WIDTH-1:0] i_alu_result,
    input  logic [DATA_WIDTH-1:0] i_mem_read_data,
    input  logic [    NB_REG-1:0] i_rd,
    input  logic [     NB_PC-1:0] i_pc_plus_1,
    input  logic                  i_RegWrite,
    input  logic                  i_MemToReg,
    input  logic                  i_Jump,
    output logic [DATA_WIDTH-1:0] o_write_data,
    output logic [    NB_REG-1:0] o_write_reg,
    output logic                  o_RegWrite
);

    // 3-way mux: Jump → pc_plus_1, MemToReg → mem_read_data, else → alu_result
    assign o_write_data = i_Jump ? i_pc_plus_1 : i_MemToReg ? i_mem_read_data : i_alu_result;

    assign o_write_reg  = i_rd;
    assign o_RegWrite   = i_RegWrite;

endmodule
