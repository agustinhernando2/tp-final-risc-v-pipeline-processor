`timescale 1ns / 1ps

module RegisterFile#(
    parameter NB_REG = 5
    parameter DATA_WIDTH = 32,

)(
    input i_clk,
    input i_reset,
    input [NB_REG-1:0] i_read_reg_1,
    input [NB_REG-1:0] i_read_reg_2,

    input [NB_REG-1:0] i_write_reg,         // register number to write
    input [DATA_WIDTH-1:0] i_write_data,    // data to write
    input i_regWrite,

    output [DATA_WIDTH-1:0] o_read_reg_1,
    output [DATA_WIDTH-1:0] o_read_reg_2,
    );

    reg [2**NB_REG-1:0] r_RF [DATA_WIDTH-1:0];

    assign o_read_reg_1 = r_RF[i_read_reg_1];
    assign o_read_reg_2 = r_RF[i_read_reg_2];

    integer i;
    always @(posedge i_clk ) begin
        if (i_reset) begin
            r_RF[0] <= 32'b10;
            r_RF[1] <= 32'b01;
            for (i = 2; i<2**NB_REG ;i=i+1) begin
                r_RF[i] <= 0;
            end
        end else begin
            if (i_regWrite) begin
                r_RF[i_write_reg] <= i_write_data;
            end
        end
    end

endmodule
