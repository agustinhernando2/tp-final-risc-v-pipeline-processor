`timescale 1ns / 1ps

module WriteBackStage #(
    parameter DATA_WIDTH = 32,
    parameter NB_REG     = 5
) (
    input  logic [DATA_WIDTH-1:0] i_alu_result,
    input  logic [DATA_WIDTH-1:0] i_mem_read_data,
    input  logic [    NB_REG-1:0] i_rd,
    input  logic                  i_RegWrite,
    input  logic                  i_MemToReg,
    output logic [DATA_WIDTH-1:0] o_write_data,
    output logic [    NB_REG-1:0] o_write_reg,
    output logic                  o_RegWrite
);

    mux1_2 #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_mux_wb (
        .i_a  (i_alu_result),
        .i_b  (i_mem_read_data),
        .i_sel(i_MemToReg),
        .o_out(o_write_data)
    );

    assign o_write_reg = i_rd;
    assign o_RegWrite  = i_RegWrite;

endmodule
