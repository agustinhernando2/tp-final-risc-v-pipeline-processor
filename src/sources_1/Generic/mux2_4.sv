`timescale 1ns / 1ps

module mux2_4 #(
    parameter DATA_WIDTH = 32
)(
    input  logic [DATA_WIDTH-1:0] i_a,
    input  logic [DATA_WIDTH-1:0] i_b,
    input  logic [DATA_WIDTH-1:0] i_c,
    input  logic [DATA_WIDTH-1:0] i_d,
    input  logic [1:0]            i_sel,

    output logic [DATA_WIDTH-1:0] o_out
);

    always_comb begin
        o_out = '0;
        unique case (i_sel)
            2'b00: o_out = i_a;
            2'b01: o_out = i_b;
            2'b10: o_out = i_c;
            2'b11: o_out = i_d;
        endcase
    end

endmodule
