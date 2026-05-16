`timescale 1ns / 1ps

module mux1_2 #(
    parameter DATA_WIDTH = 32
)(
    input  logic [DATA_WIDTH-1:0] i_a,
    input  logic [DATA_WIDTH-1:0] i_b,
    input  logic                  i_sel,

    output logic [DATA_WIDTH-1:0] o_out
);

    assign o_out = i_sel ? i_b : i_a;

endmodule
