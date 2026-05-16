`timescale 1ns / 1ps

module RegisterFile #(
    parameter NB_REG    = 5,
    parameter DATA_WIDTH = 32
)(
    input  logic                   i_clk,
    input  logic                   i_reset,
    input  logic [NB_REG-1:0]     i_read_reg_1,
    input  logic [NB_REG-1:0]     i_read_reg_2,
    input  logic [NB_REG-1:0]     i_write_reg,
    input  logic [DATA_WIDTH-1:0] i_write_data,
    input  logic                   i_regWrite,
    output logic [DATA_WIDTH-1:0] o_read_reg_1,
    output logic [DATA_WIDTH-1:0] o_read_reg_2
);

    logic [DATA_WIDTH-1:0] r_RF [0:2**NB_REG-1];

    assign o_read_reg_1 = r_RF[i_read_reg_1];
    assign o_read_reg_2 = r_RF[i_read_reg_2];

    always_ff @(posedge i_clk) begin
        if (i_reset) begin
            for (int i = 0; i < 2**NB_REG; i++)
                r_RF[i] <= '0;
        end else begin
            if (i_regWrite && i_write_reg != '0)
                r_RF[i_write_reg] <= i_write_data;
        end
    end

endmodule
