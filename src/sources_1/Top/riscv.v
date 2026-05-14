`timescale 1ns / 1ps

module RISCV#(
    parameter NB_PC = 32,
    parameter NB_INST = 32,
    parameter NB_REG = 5,
    parameter OPCODE_SIZE = 6
    )(
    input i_clk,
    input i_reset,
    input i_rx,

    output o_tx
    );

endmodule