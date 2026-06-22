`timescale 1ns / 1ps

module ControlUnit #(
    parameter OPCODE_WIDTH = 7
) (
    input  logic [OPCODE_WIDTH-1:0] i_opcode,
    output logic                    o_RegWrite,
    output logic                    o_ALUSrc,
    output logic [             1:0] o_ALUOp,
    output logic                    o_MemRead,
    output logic                    o_MemWrite,
    output logic                    o_MemToReg,
    output logic                    o_Branch,
    output logic                    o_Jump,
    output logic                    o_JumpReg,
    output logic                    o_LUI,
    output logic [             2:0] o_ImmSrc
);

    always_comb begin
        // defaults — safe NOP-like state
        o_RegWrite = 1'b0;
        o_ALUSrc   = 1'b0;
        o_ALUOp    = 2'b00;
        o_MemRead  = 1'b0;
        o_MemWrite = 1'b0;
        o_MemToReg = 1'b0;
        o_Branch   = 1'b0;
        o_Jump     = 1'b0;
        o_JumpReg  = 1'b0;
        o_LUI      = 1'b0;
        o_ImmSrc   = 3'b000;

        case (i_opcode)
            7'b0110011: begin  // R-type
                o_RegWrite = 1'b1;
                o_ALUOp    = 2'b10;
            end
            7'b0010011: begin  // I-arith (ADDI, ANDI, ORI, ...)
                o_RegWrite = 1'b1;
                o_ALUSrc   = 1'b1;
                o_ALUOp    = 2'b11;
                o_ImmSrc   = 3'b000;
            end
            7'b0000011: begin  // Load
                o_RegWrite = 1'b1;
                o_ALUSrc   = 1'b1;
                o_ALUOp    = 2'b00;
                o_MemRead  = 1'b1;
                o_MemToReg = 1'b1;
                o_ImmSrc   = 3'b000;
            end
            7'b0100011: begin  // Store
                o_ALUSrc   = 1'b1;
                o_ALUOp    = 2'b00;
                o_MemWrite = 1'b1;
                o_ImmSrc   = 3'b001;
            end
            7'b1100011: begin  // Branch (BEQ, BNE, ...)
                o_ALUOp  = 2'b01;
                o_Branch = 1'b1;
                o_ImmSrc = 3'b010;
            end
            7'b0110111: begin  // LUI
                o_RegWrite = 1'b1;
                o_ALUSrc   = 1'b1;
                o_ALUOp    = 2'b00;
                o_LUI      = 1'b1;
                o_ImmSrc   = 3'b011;
            end
            7'b1101111: begin  // JAL
                o_RegWrite = 1'b1;
                o_ALUSrc   = 1'b1;
                o_ALUOp    = 2'b00;
                o_Jump     = 1'b1;
                o_ImmSrc   = 3'b100;
            end
            7'b1100111: begin  // JALR
                o_RegWrite = 1'b1;
                o_ALUSrc   = 1'b1;
                o_ALUOp    = 2'b00;
                o_Jump     = 1'b1;
                o_JumpReg  = 1'b1;
                o_ImmSrc   = 3'b000;
            end
            default: ;
        endcase
    end

endmodule
