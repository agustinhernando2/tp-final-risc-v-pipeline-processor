`timescale 1ns / 1ps

// Modulo generico de registro de pipeline
// Puede ser usado para cualquier señal de cualquier ancho
module PosEdgeRegister#(
    parameter DATA_WIDTH = 32,
    parameter RESET_VALUE = 0
)(
    input i_clk,
    input i_reset,
    input i_enable,
    input [DATA_WIDTH-1:0] i_data,
    output [DATA_WIDTH-1:0] o_data
);

    reg [DATA_WIDTH-1:0] reg_data;

    always @(posedge i_clk) begin
        if (i_reset) begin
            reg_data <= RESET_VALUE;
        end else if (i_enable) begin
            reg_data <= i_data;
        end
    end

    assign o_data = reg_data;

endmodule

