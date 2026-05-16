`timescale 1ns / 1ps

module mux3_8 #(
    parameter DATA_WIDTH = 32
) (
    input logic [DATA_WIDTH-1:0] i_a,
    input logic [DATA_WIDTH-1:0] i_b,
    input logic [DATA_WIDTH-1:0] i_c,
    input logic [DATA_WIDTH-1:0] i_d,
    input logic [DATA_WIDTH-1:0] i_e,
    input logic [DATA_WIDTH-1:0] i_f,
    input logic [DATA_WIDTH-1:0] i_g,
    input logic [DATA_WIDTH-1:0] i_h,
    input logic [           2:0] i_sel,

    output logic [DATA_WIDTH-1:0] o_out
);

    always_comb begin
        o_out = '0;
        unique case (i_sel)
            3'b000: o_out = i_a;
            3'b001: o_out = i_b;
            3'b010: o_out = i_c;
            3'b011: o_out = i_d;
            3'b100: o_out = i_e;
            3'b101: o_out = i_f;
            3'b110: o_out = i_g;
            3'b111: o_out = i_h;
        endcase
    end

endmodule
