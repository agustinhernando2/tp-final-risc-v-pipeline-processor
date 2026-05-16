`timescale 1ns / 1ps

// Decodes all five RISC-V RV32I immediate formats.
// ImmSrc selects the format; the full instruction word
//
// ImmSrc encoding:
//   3'b000 — I-type  (inst[31:20])
//   3'b001 — S-type  ({inst[31:25], inst[11:7]})
//   3'b010 — B-type  ({inst[31], inst[7], inst[30:25], inst[11:8], 1'b0})
//   3'b011 — U-type  ({inst[31:12], 12'b0})
//   3'b100 — J-type  ({inst[31], inst[19:12], inst[20], inst[30:21], 1'b0})

module ImmediateExtend #(
    parameter DATA_WIDTH = 32
)(
    input  logic [DATA_WIDTH-1:0] i_instruction,
    input  logic [2:0]            i_ImmSrc,
    output logic [DATA_WIDTH-1:0] o_immediate
);

    always_comb begin
        unique case (i_ImmSrc)
            3'b000: // I-type
                o_immediate = {{20{i_instruction[31]}}, i_instruction[31:20]};

            3'b001: // S-type
                o_immediate = {{20{i_instruction[31]}}, i_instruction[31:25], i_instruction[11:7]};

            3'b010: // B-type
                o_immediate = {{19{i_instruction[31]}}, i_instruction[31], i_instruction[7],
                               i_instruction[30:25], i_instruction[11:8], 1'b0};

            3'b011: // U-type
                o_immediate = {i_instruction[31:12], 12'b0};

            3'b100: // J-type
                o_immediate = {{11{i_instruction[31]}}, i_instruction[31], i_instruction[19:12],
                               i_instruction[20], i_instruction[30:21], 1'b0};

            default:
                o_immediate = '0;
        endcase
    end

endmodule
