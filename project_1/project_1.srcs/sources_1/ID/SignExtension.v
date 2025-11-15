`timescale 1ns / 1ps

module SignExtension#(
    parameter IMMEDIATE_SIZE = 12,
    parameter DATA_SIZE = 64
)(
    input [IMMEDIATE_SIZE-1:0] i_immediate,
    output [DATA_SIZE-1:0] o_extended
    );

    assign o_extended = { {DATA_SIZE-IMMEDIATE_SIZE{ i_immediate[IMMEDIATE_SIZE-1] }}, i_immediate };
endmodule
