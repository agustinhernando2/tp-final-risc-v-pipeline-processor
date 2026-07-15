`timescale 1ns / 1ps

module DataMemory #(
    parameter DATA_WIDTH = 32,
    parameter NB_ADDR    = 6   // 64 words
) (
    input logic i_clk,
    input logic i_reset,
    input logic [NB_ADDR-1:0] i_addr,
    input logic [DATA_WIDTH-1:0] i_write_data,
    input logic i_mem_write,
    input  logic [2:0]               i_funct3,  // Selects width: 000=byte, 001=halfword, 010=word, 100=byte unsigned, 101=halfword unsigned, 110=word unsigned

    output logic [DATA_WIDTH-1:0] o_read_data,
    // Debug read port (used by the DebugUnit to dump data memory; raw word, no extension)
    input  logic [   NB_ADDR-1:0] i_dbg_addr,
    output logic [DATA_WIDTH-1:0] o_dbg_data
);

    logic [DATA_WIDTH-1:0] r_mem[2**NB_ADDR-1:0];

    // Synchronous write with byte/halfword/word granularity
    // always_ff @(posedge i_clk) begin
    //     if (i_reset) begin
    //         for (int i = 0; i < 2 ** NB_ADDR; i++) r_mem[i] <= '0;
    //     end else if (i_mem_write) begin
    //         case (i_funct3[1:0])
    //             2'b00:   r_mem[i_addr][7:0] <= i_write_data[7:0];  // SB: byte
    //             2'b01:   r_mem[i_addr][15:0] <= i_write_data[15:0];  // SH: halfword
    //             2'b10:   r_mem[i_addr] <= i_write_data;  // SW: word
    //             default: r_mem[i_addr] <= i_write_data;
    //         endcase
    //     end
    // end
    always_ff @(posedge i_clk) begin
        if (i_mem_write) begin
            case (i_funct3[1:0])
                2'b00:   r_mem[i_addr][7:0] <= i_write_data[7:0];  // SB: byte
                2'b01:   r_mem[i_addr][15:0] <= i_write_data[15:0];  // SH: halfword
                2'b10:   r_mem[i_addr] <= i_write_data;  // SW: word
                default: r_mem[i_addr] <= i_write_data;
            endcase
        end
    end

    // Combinational read with sign/zero extension based on funct3
    always_comb begin
        case (i_funct3)

            // LB: byte sign-extended
            3'b000: o_read_data = {{(DATA_WIDTH - 8) {r_mem[i_addr][7]}}, r_mem[i_addr][7:0]};

            // LH: halfword sign-extended
            3'b001: o_read_data = {{(DATA_WIDTH - 16) {r_mem[i_addr][15]}}, r_mem[i_addr][15:0]};

            // LW: word
            3'b010: o_read_data = r_mem[i_addr];

            // LBU: byte zero-extended
            3'b100: o_read_data = {{(DATA_WIDTH - 8) {1'b0}}, r_mem[i_addr][7:0]};

            // LHU: halfword zero-extended
            3'b101: o_read_data = {{(DATA_WIDTH - 16) {1'b0}}, r_mem[i_addr][15:0]};

            // LWU: word zero-extended (same as LW for 32-bit)
            3'b110:  o_read_data = r_mem[i_addr];
            default: o_read_data = r_mem[i_addr];
        endcase
    end

    // Debug read: raw stored word at the requested index.
    assign o_dbg_data = r_mem[i_dbg_addr];

endmodule
