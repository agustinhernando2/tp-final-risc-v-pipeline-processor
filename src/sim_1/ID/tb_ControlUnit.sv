`timescale 1ns / 1ps

module tb_ControlUnit;

    logic [6:0] opcode;
    logic RegWrite, ALUSrc, MemRead, MemWrite, MemToReg, Branch, Jump;
    logic [1:0] ALUOp;
    logic [2:0] ImmSrc;

    ControlUnit #(
        .OPCODE_WIDTH(7)
    ) DUT (
        .i_opcode  (opcode),
        .o_RegWrite(RegWrite),
        .o_ALUSrc  (ALUSrc),
        .o_ALUOp   (ALUOp),
        .o_MemRead (MemRead),
        .o_MemWrite(MemWrite),
        .o_MemToReg(MemToReg),
        .o_Branch  (Branch),
        .o_Jump    (Jump),
        .o_ImmSrc  (ImmSrc)
    );

    int pass_count = 0;
    int fail_count = 0;

    task automatic check(input string name, input logic exp_RegWrite, input logic exp_ALUSrc,
                         input logic [1:0] exp_ALUOp, input logic exp_MemRead,
                         input logic exp_MemWrite, input logic exp_MemToReg, input logic exp_Branch,
                         input logic exp_Jump, input logic [2:0] exp_ImmSrc);
        #1;  // let combinational settle
        if (RegWrite !== exp_RegWrite || ALUSrc !== exp_ALUSrc || ALUOp !== exp_ALUOp ||
            MemRead !== exp_MemRead   || MemWrite !== exp_MemWrite ||
            MemToReg !== exp_MemToReg || Branch !== exp_Branch ||
            Jump !== exp_Jump         || ImmSrc !== exp_ImmSrc) begin
            $display(
                "FAIL [%s] opcode=%07b | got RegWrite=%b ALUSrc=%b ALUOp=%02b MemRead=%b MemWrite=%b MemToReg=%b Branch=%b Jump=%b ImmSrc=%03b",
                name, opcode, RegWrite, ALUSrc, ALUOp, MemRead, MemWrite, MemToReg, Branch, Jump,
                ImmSrc);
            $display(
                "     expected         RegWrite=%b ALUSrc=%b ALUOp=%02b MemRead=%b MemWrite=%b MemToReg=%b Branch=%b Jump=%b ImmSrc=%03b",
                exp_RegWrite, exp_ALUSrc, exp_ALUOp, exp_MemRead, exp_MemWrite, exp_MemToReg,
                exp_Branch, exp_Jump, exp_ImmSrc);
            fail_count++;
        end else begin
            $display("PASS [%s]", name);
            pass_count++;
        end
    endtask

    initial begin
        // R-type  (opcode=0110011): RegWrite=1 ALUSrc=0 ALUOp=10 MemRead=0 MemWrite=0 MemToReg=0 Branch=0 Jump=0 ImmSrc=000
        opcode = 7'b0110011;
        check("R-type", 1, 0, 2'b10, 0, 0, 0, 0, 0, 3'b000);

        // I-arith (opcode=0010011): RegWrite=1 ALUSrc=1 ALUOp=11 MemRead=0 MemWrite=0 MemToReg=0 Branch=0 Jump=0 ImmSrc=000
        opcode = 7'b0010011;
        check("I-arith", 1, 1, 2'b11, 0, 0, 0, 0, 0, 3'b000);

        // Load    (opcode=0000011): RegWrite=1 ALUSrc=1 ALUOp=00 MemRead=1 MemWrite=0 MemToReg=1 Branch=0 Jump=0 ImmSrc=000
        opcode = 7'b0000011;
        check("Load", 1, 1, 2'b00, 1, 0, 1, 0, 0, 3'b000);

        // Store   (opcode=0100011): RegWrite=0 ALUSrc=1 ALUOp=00 MemRead=0 MemWrite=1 MemToReg=0 Branch=0 Jump=0 ImmSrc=001
        opcode = 7'b0100011;
        check("Store", 0, 1, 2'b00, 0, 1, 0, 0, 0, 3'b001);

        // Branch  (opcode=1100011): RegWrite=0 ALUSrc=0 ALUOp=01 MemRead=0 MemWrite=0 MemToReg=0 Branch=1 Jump=0 ImmSrc=010
        opcode = 7'b1100011;
        check("Branch", 0, 0, 2'b01, 0, 0, 0, 1, 0, 3'b010);

        // LUI     (opcode=0110111): RegWrite=1 ALUSrc=1 ALUOp=11 MemRead=0 MemWrite=0 MemToReg=0 Branch=0 Jump=0 ImmSrc=011
        opcode = 7'b0110111;
        check("LUI", 1, 1, 2'b11, 0, 0, 0, 0, 0, 3'b011);

        // JAL     (opcode=1101111): RegWrite=1 ALUSrc=1 ALUOp=00 MemRead=0 MemWrite=0 MemToReg=0 Branch=0 Jump=1 ImmSrc=100
        opcode = 7'b1101111;
        check("JAL", 1, 1, 2'b00, 0, 0, 0, 0, 1, 3'b100);

        // JALR    (opcode=1100111): RegWrite=1 ALUSrc=1 ALUOp=00 MemRead=0 MemWrite=0 MemToReg=0 Branch=0 Jump=1 ImmSrc=000
        opcode = 7'b1100111;
        check("JALR", 1, 1, 2'b00, 0, 0, 0, 0, 1, 3'b000);

        // default / unknown opcode: all zeros
        opcode = 7'b1111111;
        check("default", 0, 0, 2'b00, 0, 0, 0, 0, 0, 3'b000);

        $display("-----------------------------");
        $display("Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
