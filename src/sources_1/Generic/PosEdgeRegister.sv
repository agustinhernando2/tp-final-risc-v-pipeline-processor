`timescale 1ns / 1ps

module PosEdgeRegister #(
    parameter DATA_WIDTH  = 32,
    parameter RESET_VALUE = 0
)(
    input  logic                  i_clk,
    input  logic                  i_reset,
    input  logic                  i_enable,
    input  logic [DATA_WIDTH-1:0] i_data,

    output logic [DATA_WIDTH-1:0] o_data
);

    logic [DATA_WIDTH-1:0] r_data;

    always_ff @(posedge i_clk) begin
        if (i_reset)
            r_data <= DATA_WIDTH'(RESET_VALUE);
        else if (i_enable)
            r_data <= i_data;
    end

    assign o_data = r_data;

endmodule
