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

    logic [DATA_WIDTH-1:0] w_alu_or_mem;

    // Mux 1: select ALU result (R/I-type) or memory read data (Load)
    mux1_2 #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_mux_mem_to_reg (
        .i_a  (i_alu_result),
        .i_b  (i_mem_read_data),
        .i_sel(i_MemToReg),
        .o_out(w_alu_or_mem)
    );

    // Mux 2: JAL/JALR override with PC+1 as the return address written to rd
    mux1_2 #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_mux_jump (
        .i_a  (w_alu_or_mem),
        .i_b  (i_pc_plus_1),
        .i_sel(i_Jump),
        .o_out(o_write_data)
    );

    assign o_write_reg = i_rd;
    assign o_RegWrite  = i_RegWrite;

endmodule
