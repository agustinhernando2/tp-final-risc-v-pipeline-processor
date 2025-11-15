`timescale 1ns / 1ps

// Adder generico: Suma dos operandos de N bits
module Adder#(
    parameter DATA_WIDTH = 32
)(
    input [DATA_WIDTH-1:0] i_operand_a,
    input [DATA_WIDTH-1:0] i_operand_b,
    
    output [DATA_WIDTH-1:0] o_sum
);

    assign o_sum = i_operand_a + i_operand_b;
    
endmodule
