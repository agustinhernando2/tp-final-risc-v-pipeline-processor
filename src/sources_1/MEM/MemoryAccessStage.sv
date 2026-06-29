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
    // debug read port (forwarded from DataMemory for the DebugUnit dump)
    input  logic [   NB_ADDR-1:0] i_dbg_addr,
    output logic [DATA_WIDTH-1:0] o_dbg_data,
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
        .o_read_data (o_mem_read_data),
        .i_dbg_addr  (i_dbg_addr),
        .o_dbg_data  (o_dbg_data)
    );

    // BEQ: taken when zero=1 (funct3[0]=0), BNE: taken when zero=0 (funct3[0]=1)
    assign o_PCSrc = (i_Branch & (i_zero ^ i_funct3[0])) | i_Jump;

    // JALR uses ALU result (rs1 + imm); JAL/branch use precomputed branch_target.
    // The ALU result is DATA_WIDTH wide and the PC is NB_PC wide; cast to PC width
    // (zero-extends when DATA_WIDTH < NB_PC, e.g. 32-bit datapath with 64-bit PC).
    logic [NB_PC-1:0] w_alu_pc_target;
    assign w_alu_pc_target = NB_PC'(i_alu_result);

    mux1_2 #(
        .DATA_WIDTH(NB_PC)
    ) u_pc_branch_mux (
        .i_a  (i_branch_target),
        .i_b  (w_alu_pc_target),
        .i_sel(i_JumpReg),
        .o_out(o_PCBranch)
    );

endmodule
