`timescale 1ns / 1ps

// Mux generico 
module mux2_4 #(
    parameter DATA_WIDTH = 32
)(
    input [DATA_WIDTH-1:0] a, b, c, d,
    input [1:0]sel,

    output [DATA_WIDTH-1:0] out
);

    always @ (*) begin
        case (sel)
            2'b00 : out = a;
            2'b01 : out = b;
            2'b10 : out = c;
            2'b11 : out = d;
        endcase
    end
endmodule