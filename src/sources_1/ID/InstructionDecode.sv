`timescale 1ns / 1ps

module instructionDecode #(
    parameter NB_INST    = 32,
    parameter NB_REG     = 5,
    parameter DATA_WIDTH = 32
) (
    input  logic                  i_clk,
    input  logic                  i_reset,
    input  logic [   NB_INST-1:0] i_instruction,
    // WB feedback
    input  logic [    NB_REG-1:0] i_write_reg,
    input  logic [DATA_WIDTH-1:0] i_write_data,
    input  logic                  i_regWrite,
    // data outputs
    output logic [DATA_WIDTH-1:0] o_read_data_1,
    output logic [DATA_WIDTH-1:0] o_read_data_2,
    output logic [    NB_REG-1:0] o_rd,
    output logic [DATA_WIDTH-1:0] o_immediate,
    // instruction fields forwarded to EX
    output logic [           2:0] o_funct3,
    output logic                  o_funct7_5,
    // control signals
    output logic                  o_RegWrite,
    output logic                  o_ALUSrc,
    output logic [           1:0] o_ALUOp,
    output logic                  o_MemRead,
    output logic                  o_MemWrite,
    output logic                  o_MemToReg,
    output logic                  o_Branch,
    output logic                  o_Jump,
    output logic                  o_JumpReg
);

    logic [NB_REG-1:0] w_rs1, w_rs2;
    logic [2:0] w_ImmSrc;

    assign w_rs1      = i_instruction[19:15];
    assign w_rs2      = i_instruction[24:20];
    assign o_rd       = i_instruction[11:7];
    assign o_funct3   = i_instruction[14:12];
    assign o_funct7_5 = i_instruction[30];

    ControlUnit #(
        .OPCODE_WIDTH(7)
    ) CU (
        .i_opcode  (i_instruction[6:0]),
        .o_RegWrite(o_RegWrite),
        .o_ALUSrc  (o_ALUSrc),
        .o_ALUOp   (o_ALUOp),
        .o_MemRead (o_MemRead),
        .o_MemWrite(o_MemWrite),
        .o_MemToReg(o_MemToReg),
        .o_Branch  (o_Branch),
        .o_Jump    (o_Jump),
        .o_JumpReg (o_JumpReg),
        .o_ImmSrc  (w_ImmSrc)
    );

    RegisterFile #(
        .NB_REG(NB_REG),
        .DATA_WIDTH(DATA_WIDTH)
    ) RF (
        .i_clk       (i_clk),
        .i_reset     (i_reset),
        .i_read_reg_1(w_rs1),
        .i_read_reg_2(w_rs2),
        .i_write_reg (i_write_reg),
        .i_write_data(i_write_data),
        .i_regWrite  (i_regWrite),
        .o_read_reg_1(o_read_data_1),
        .o_read_reg_2(o_read_data_2)
    );

    ImmediateExtend #(
        .DATA_WIDTH(DATA_WIDTH)
    ) IMM (
        .i_instruction(i_instruction),
        .i_ImmSrc     (w_ImmSrc),
        .o_immediate  (o_immediate)
    );

endmodule
