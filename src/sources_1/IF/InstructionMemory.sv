`timescale 1ns / 1ps

module InstructionMemory #(
    parameter NB_PC   = 32,
    parameter NB_INST = 32,
    parameter NB_ADDR = 8
) (
    input logic               i_clk,
    input logic               i_reset,
    input logic [  NB_PC-1:0] i_PC,
    input logic               i_imem_wr,
    input logic [NB_ADDR-1:0] i_imem_addr,
    input logic [NB_INST-1:0] i_imem_data,

    output logic [NB_INST-1:0] o_instruction
);

    logic [NB_INST-1:0] r_mem[2**NB_ADDR-1:0];

    initial begin
        for (int i = 0; i < 2 ** NB_ADDR; i++) r_mem[i] = '0;
        $readmemh("program.hex", r_mem);
    end

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            for (int i = 0; i < 2 ** NB_ADDR; i++) r_mem[i] <= '0;
        end else if (i_imem_wr) begin
            r_mem[i_imem_addr] <= i_imem_data;
        end
    end

    // PC is byte-addressed; instructions are word-aligned → index = PC >> 2
    assign o_instruction = r_mem[i_PC[NB_ADDR+1:2]];

endmodule
