`timescale 1ns / 1ps

module ALU #(
    parameter DATA_WIDTH     = 32,
    parameter ALU_CTRL_WIDTH = 4
)(
    input  logic [DATA_WIDTH-1:0]     i_operand_a,
    input  logic [DATA_WIDTH-1:0]     i_operand_b,
    input  logic [ALU_CTRL_WIDTH-1:0] i_ALUCtrl,
    output logic [DATA_WIDTH-1:0]     o_result,
    output logic                      o_zero
);

    always_comb begin
        unique case (i_ALUCtrl)
            4'b0000: o_result = i_operand_a + i_operand_b;                                   // ADD
            4'b0001: o_result = i_operand_a - i_operand_b;                                   // SUB
            4'b0010: o_result = i_operand_a << i_operand_b[4:0];                             // SLL; b: 0–31 positions
            4'b0011: o_result = {{(DATA_WIDTH-1){1'b0}}, $signed(i_operand_a) < $signed(i_operand_b)}; // SLT
            4'b0100: o_result = {{(DATA_WIDTH-1){1'b0}}, i_operand_a < i_operand_b};         // SLTU
            4'b0101: o_result = i_operand_a ^ i_operand_b;                                   // XOR
            4'b0110: o_result = i_operand_a >> i_operand_b[4:0];                             // SRL b: 0–31 positions
            4'b0111: o_result = DATA_WIDTH'($signed(i_operand_a) >>> i_operand_b[4:0]);      // SRA; signed
            4'b1000: o_result = i_operand_a | i_operand_b;                                   // OR
            4'b1001: o_result = i_operand_a & i_operand_b;                                   // AND
            default: o_result = '0;
        endcase
    end

    assign o_zero = (o_result == '0);

endmodule
