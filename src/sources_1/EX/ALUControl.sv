`timescale 1ns / 1ps

module ALUControl #(
    parameter ALU_CTRL_WIDTH = 4
) (
    input  logic [               1:0] i_ALUOp,
    input  logic [               2:0] i_funct3,
    input  logic                      i_funct7_5,
    output logic [ALU_CTRL_WIDTH-1:0] o_ALUCtrl
);

    always_comb begin
        casez ({
            i_ALUOp, i_funct3, i_funct7_5
        })
            // ALUOp=00: forced ADD (load/store address calc)
            6'b00_???_?: o_ALUCtrl = 4'b0000;
            // ALUOp=01: forced SUB (branch compare)
            6'b01_???_?: o_ALUCtrl = 4'b0001;
            // ALUOp=10: R-type, decode funct3+funct7[5]
            6'b10_000_0: o_ALUCtrl = 4'b0000;  // ADD
            6'b10_000_1: o_ALUCtrl = 4'b0001;  // SUB
            6'b10_001_?: o_ALUCtrl = 4'b0010;  // SLL
            6'b10_010_?: o_ALUCtrl = 4'b0011;  // SLT
            6'b10_011_?: o_ALUCtrl = 4'b0100;  // SLTU
            6'b10_100_?: o_ALUCtrl = 4'b0101;  // XOR
            6'b10_101_0: o_ALUCtrl = 4'b0110;  // SRL
            6'b10_101_1: o_ALUCtrl = 4'b0111;  // SRA
            6'b10_110_?: o_ALUCtrl = 4'b1000;  // OR
            6'b10_111_?: o_ALUCtrl = 4'b1001;  // AND
            // ALUOp=11: I-type ALU, decode funct3 (funct7[5] distinguishes SRLI/SRAI)
            6'b11_000_?: o_ALUCtrl = 4'b0000;  // ADDI
            6'b11_001_?: o_ALUCtrl = 4'b0010;  // SLLI
            6'b11_010_?: o_ALUCtrl = 4'b0011;  // SLTI
            6'b11_011_?: o_ALUCtrl = 4'b0100;  // SLTIU
            6'b11_100_?: o_ALUCtrl = 4'b0101;  // XORI
            6'b11_101_0: o_ALUCtrl = 4'b0110;  // SRLI
            6'b11_101_1: o_ALUCtrl = 4'b0111;  // SRAI
            6'b11_110_?: o_ALUCtrl = 4'b1000;  // ORI
            6'b11_111_?: o_ALUCtrl = 4'b1001;  // ANDI
            default:     o_ALUCtrl = 4'b0000;
        endcase
    end

endmodule
