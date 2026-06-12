`timescale 1ns / 1ps

module MemoryAccessStage #(
    parameter DATA_WIDTH = 64,
    parameter NB_PC      = 64,
    parameter NB_ADDR    = 6
) (
    input  logic                  i_clk,
    input  logic                  i_reset,
    // from EX/MEM buffer
    input  logic [DATA_WIDTH-1:0] i_alu_result,
    input  logic                  i_zero,
    input  logic [DATA_WIDTH-1:0] i_read_data_2,
    input  logic [           2:0] i_funct3,
    input  logic [     NB_PC-1:0] i_branch_target,
    input  logic                  i_MemWrite,
    input  logic                  i_Branch,
    input  logic                  i_Jump,
    input  logic                  i_JumpReg,
    // outputs
    output logic [DATA_WIDTH-1:0] o_mem_read_data,
    output logic                  o_PCSrc,
    output logic [     NB_PC-1:0] o_PCBranch
);

    DataMemory #(
        .DATA_WIDTH(DATA_WIDTH),
        .NB_ADDR   (NB_ADDR)
    ) u_data_memory (
        .i_clk       (i_clk),
        .i_reset     (i_reset),
        .i_addr      (i_alu_result[NB_ADDR-1:0]),
        .i_write_data(i_read_data_2),
        .i_mem_write (i_MemWrite),
        .i_funct3    (i_funct3),
        .o_read_data (o_mem_read_data)
    );

    // BEQ: taken when zero=1 (funct3[0]=0), BNE: taken when zero=0 (funct3[0]=1)
    assign o_PCSrc = (i_Branch & (i_zero ^ i_funct3[0])) | i_Jump;

    // JALR uses ALU result (rs1 + imm); JAL/branch use precomputed branch_target
    mux1_2 #(
        .DATA_WIDTH(NB_PC)
    ) u_pc_branch_mux (
        .i_a  (i_branch_target),
        .i_b  (i_alu_result[NB_PC-1:0]),
        .i_sel(i_JumpReg),
        .o_out(o_PCBranch)
    );

endmodule
