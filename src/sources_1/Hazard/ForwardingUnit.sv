`timescale 1ns / 1ps

// Forwarding unit for EX stage data hazards.
// ForwardA/B encoding: 00=register file, 01=MEM/WB write-back, 10=EX/MEM ALU result.
module ForwardingUnit #(
    parameter NB_REG = 5
) (
    // Source registers of the instruction currently in EX
    input  logic [NB_REG-1:0] i_id_ex_rs1,
    input  logic [NB_REG-1:0] i_id_ex_rs2,
    // EX/MEM pipeline buffer (one stage ahead)
    input  logic [NB_REG-1:0] i_ex_mem_rd,
    input  logic              i_ex_mem_RegWrite,
    // MEM/WB pipeline buffer (two stages ahead)
    input  logic [NB_REG-1:0] i_mem_wb_rd,
    input  logic              i_mem_wb_RegWrite,
    // Forwarding selects
    output logic [       1:0] o_ForwardA,
    output logic [       1:0] o_ForwardB
);

    always_comb begin
        // EX/MEM forwarding takes priority over MEM/WB
        if (i_ex_mem_RegWrite && i_ex_mem_rd != '0 && i_ex_mem_rd == i_id_ex_rs1)
            o_ForwardA = 2'b10;
        else if (i_mem_wb_RegWrite && i_mem_wb_rd != '0 && i_mem_wb_rd == i_id_ex_rs1)
            o_ForwardA = 2'b01;
        else o_ForwardA = 2'b00;

        if (i_ex_mem_RegWrite && i_ex_mem_rd != '0 && i_ex_mem_rd == i_id_ex_rs2)
            o_ForwardB = 2'b10;
        else if (i_mem_wb_RegWrite && i_mem_wb_rd != '0 && i_mem_wb_rd == i_id_ex_rs2)
            o_ForwardB = 2'b01;
        else o_ForwardB = 2'b00;
    end

endmodule
