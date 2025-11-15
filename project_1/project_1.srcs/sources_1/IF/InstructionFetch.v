`timescale 1ns / 1ps

module InstructionFetch#(
    parameter NB_PC = 32,
    parameter NB_inst = 32,
    parameter NB_ADDR = 8
)(
    input i_clk,
    input i_reset,
    input i_enable,
    input i_PCSrc,
    input [NB_PC-1:0] i_PCBranch,
    input i_mem_wr,
    input [NB_ADDR-1:0] i_mem_addr,
    input [NB_inst-1:0 ]i_mem_data,

    output [NB_PC-1:0] o_PC_increment,
    output [NB_inst-1:0] o_instruction,
    output [NB_PC-1:0] o_PC
    );

wire [NB_PC-1:0] w_PC; // Cable que va desde PC a PC_increment y a la mem de instrucciones
wire [NB_PC-1:0] w_muxPC;

// Instancia PC using pipeline register
PosEdgeRegister#(
    .DATA_WIDTH(NB_PC),
    .RESET_VALUE(0)
)PC(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_enable(i_enable),
    .i_data(w_muxPC),
    .o_data(w_PC)
);

// Instancia PC-incremennt
Adder#(
    .NB_PC(NB_PC)
)PC_increment(
    .i_operand_a(w_PC),
    .i_operand_b(1'b1),
    .o_sum(o_PC_increment)
);

// Instancia instructionMemory
InstructionMemory#(
    .NB_PC(NB_PC),
    .NB_inst(NB_inst),
    .NB_ADDR(NB_ADDR)
)InstructionMemory(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_PC(w_PC),
    .i_mem_wr(i_mem_wr),
    .i_mem_addr(i_mem_addr),
    .i_mem_data(i_mem_data),
    .o_instruction(o_instruction)
);

assign w_muxPC = i_PCSrc ? i_PCBranch : o_PC_increment; // Si i_PCSrc es 1, w_muxPC = i_PCBranch, si no o_PC_increment.
assign o_PC = w_PC;
endmodule
