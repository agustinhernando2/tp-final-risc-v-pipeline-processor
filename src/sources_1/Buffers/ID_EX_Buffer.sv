`timescale 1ns / 1ps

module ID_EX_Buffer #(
    parameter NB_PC      = 32,
    parameter DATA_WIDTH = 32,
    parameter NB_REG     = 5
) (
    input  logic                  i_clk,
    input  logic                  i_reset,
    input  logic                  i_enable,
    input  logic                  i_flush,
    // data signals
    input  logic [     NB_PC-1:0] i_PC,
    input  logic [     NB_PC-1:0] i_pc_plus_1,
    input  logic [DATA_WIDTH-1:0] i_read_data_1,
    input  logic [DATA_WIDTH-1:0] i_read_data_2,
    input  logic [DATA_WIDTH-1:0] i_immediate,
    input  logic [    NB_REG-1:0] i_rs1,
    input  logic [    NB_REG-1:0] i_rs2,
    input  logic [    NB_REG-1:0] i_rd,
    input  logic [           2:0] i_funct3,
    input  logic                  i_funct7_5,
    // control signals
    input  logic                  i_ALUSrc,
    input  logic [           1:0] i_ALUOp,
    input  logic                  i_RegWrite,
    input  logic                  i_MemRead,
    input  logic                  i_MemWrite,
    input  logic                  i_MemToReg,
    input  logic                  i_Branch,
    input  logic                  i_Jump,
    input  logic                  i_JumpReg,
    // outputs (mirror)
    output logic [     NB_PC-1:0] o_PC,
    output logic [     NB_PC-1:0] o_pc_plus_1,
    output logic [DATA_WIDTH-1:0] o_read_data_1,
    output logic [DATA_WIDTH-1:0] o_read_data_2,
    output logic [DATA_WIDTH-1:0] o_immediate,
    output logic [    NB_REG-1:0] o_rs1,
    output logic [    NB_REG-1:0] o_rs2,
    output logic [    NB_REG-1:0] o_rd,
    output logic [           2:0] o_funct3,
    output logic                  o_funct7_5,
    output logic                  o_ALUSrc,
    output logic [           1:0] o_ALUOp,
    output logic                  o_RegWrite,
    output logic                  o_MemRead,
    output logic                  o_MemWrite,
    output logic                  o_MemToReg,
    output logic                  o_Branch,
    output logic                  o_Jump,
    output logic                  o_JumpReg
);

    always_ff @(posedge i_clk) begin
        if (i_reset || i_flush) begin
            o_PC          <= '0;
            o_pc_plus_1   <= '0;
            o_read_data_1 <= '0;
            o_read_data_2 <= '0;
            o_immediate   <= '0;
            o_rs1         <= '0;
            o_rs2         <= '0;
            o_rd          <= '0;
            o_funct3      <= '0;
            o_funct7_5    <= '0;
            o_ALUSrc      <= '0;
            o_ALUOp       <= '0;
            o_RegWrite    <= '0;
            o_MemRead     <= '0;
            o_MemWrite    <= '0;
            o_MemToReg    <= '0;
            o_Branch      <= '0;
            o_Jump        <= '0;
            o_JumpReg     <= '0;
        end else if (i_enable) begin
            o_PC          <= i_PC;
            o_pc_plus_1   <= i_pc_plus_1;
            o_read_data_1 <= i_read_data_1;
            o_read_data_2 <= i_read_data_2;
            o_immediate   <= i_immediate;
            o_rs1         <= i_rs1;
            o_rs2         <= i_rs2;
            o_rd          <= i_rd;
            o_funct3      <= i_funct3;
            o_funct7_5    <= i_funct7_5;
            o_ALUSrc      <= i_ALUSrc;
            o_ALUOp       <= i_ALUOp;
            o_RegWrite    <= i_RegWrite;
            o_MemRead     <= i_MemRead;
            o_MemWrite    <= i_MemWrite;
            o_MemToReg    <= i_MemToReg;
            o_Branch      <= i_Branch;
            o_Jump        <= i_Jump;
            o_JumpReg     <= i_JumpReg;
        end
    end

endmodule
