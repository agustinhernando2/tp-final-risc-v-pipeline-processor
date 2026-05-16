`timescale 1ns / 1ps

module Adder #(
    parameter DATA_WIDTH = 32
)(
    input  logic [DATA_WIDTH-1:0] i_operand_a,
    input  logic [DATA_WIDTH-1:0] i_operand_b,

    output logic [DATA_WIDTH-1:0] o_sum
);

    assign o_sum = i_operand_a + i_operand_b;

endmodule
