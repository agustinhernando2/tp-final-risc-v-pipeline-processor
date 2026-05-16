`timescale 1ns / 1ps

// Detects load-use data hazards and inserts a stall bubble.
// A stall is needed when a load (MemRead=1) in EX is followed immediately
// by an instruction in ID that reads the same register.
module HazardDetectionUnit #(
    parameter NB_REG = 5
) (
    // Instruction currently in EX stage (from ID/EX buffer)
    input  logic              i_id_ex_MemRead,
    input  logic [NB_REG-1:0] i_id_ex_rd,
    // Instruction currently in ID stage (from IF/ID instruction word)
    input  logic [NB_REG-1:0] i_if_id_rs1,
    input  logic [NB_REG-1:0] i_if_id_rs2,
    // Control outputs
    output logic              o_PCWrite,        // 0 = freeze PC
    output logic              o_IF_ID_Write,    // 0 = freeze IF/ID buffer
    output logic              o_ID_EX_flush     // 1 = insert NOP bubble into ID/EX
);

    always_comb begin
        if (i_id_ex_MemRead && i_id_ex_rd != '0 &&
            (i_id_ex_rd == i_if_id_rs1 || i_id_ex_rd == i_if_id_rs2)) begin
            o_PCWrite     = 1'b0;
            o_IF_ID_Write = 1'b0;
            o_ID_EX_flush = 1'b1;
        end else begin
            o_PCWrite     = 1'b1;
            o_IF_ID_Write = 1'b1;
            o_ID_EX_flush = 1'b0;
        end
    end

endmodule
