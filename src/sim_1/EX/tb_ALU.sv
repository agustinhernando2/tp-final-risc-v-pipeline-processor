`timescale 1ns / 1ps

module tb_ALU;

    parameter DATA_WIDTH     = 32;
    parameter ALU_CTRL_WIDTH = 4;

    logic [DATA_WIDTH-1:0]     i_operand_a;
    logic [DATA_WIDTH-1:0]     i_operand_b;
    logic [ALU_CTRL_WIDTH-1:0] i_ALUCtrl;
    logic [DATA_WIDTH-1:0]     o_result;
    logic                      o_zero;

    ALU #(.DATA_WIDTH(DATA_WIDTH), .ALU_CTRL_WIDTH(ALU_CTRL_WIDTH)) dut (
        .i_operand_a (i_operand_a),
        .i_operand_b (i_operand_b),
        .i_ALUCtrl   (i_ALUCtrl),
        .o_result    (o_result),
        .o_zero      (o_zero)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    task automatic check(
        input string        name,
        input logic [DATA_WIDTH-1:0] expected_result,
        input logic         expected_zero
    );
        #1;
        if (o_result !== expected_result || o_zero !== expected_zero) begin
            $display("FAIL [%s]: a=%0d b=%0d ctrl=%b => result=%0d (exp %0d), zero=%b (exp %b)",
                     name, $signed(i_operand_a), $signed(i_operand_b), i_ALUCtrl,
                     $signed(o_result), $signed(expected_result), o_zero, expected_zero);
            fail_count++;
        end else begin
            $display("PASS [%s]", name);
            pass_count++;
        end
    endtask

    initial begin
        // ADD: 5 + 3 = 8
        i_operand_a = 32'd5; i_operand_b = 32'd3; i_ALUCtrl = 4'b0000;
        check("ADD 5+3", 32'd8, 1'b0);

        // ADD zero result
        i_operand_a = 32'd0; i_operand_b = 32'd0; i_ALUCtrl = 4'b0000;
        check("ADD 0+0 zero flag", 32'd0, 1'b1);

        // SUB: 10 - 3 = 7
        i_operand_a = 32'd10; i_operand_b = 32'd3; i_ALUCtrl = 4'b0001;
        check("SUB 10-3", 32'd7, 1'b0);

        // SUB equal => zero
        i_operand_a = 32'd7; i_operand_b = 32'd7; i_ALUCtrl = 4'b0001;
        check("SUB 7-7 zero flag", 32'd0, 1'b1);

        // SLL: 1 << 4 = 16
        i_operand_a = 32'd1; i_operand_b = 32'd4; i_ALUCtrl = 4'b0010;
        check("SLL 1<<4", 32'd16, 1'b0);

        // SLL: shift by 0
        i_operand_a = 32'd5; i_operand_b = 32'd0; i_ALUCtrl = 4'b0010;
        check("SLL shift 0", 32'd5, 1'b0);

        // SLL: shift by 31
        i_operand_a = 32'd1; i_operand_b = 32'd31; i_ALUCtrl = 4'b0010;
        check("SLL 1<<31", 32'h8000_0000, 1'b0);

        // SLT: -1 < 1 (signed)
        i_operand_a = 32'hFFFF_FFFF; i_operand_b = 32'd1; i_ALUCtrl = 4'b0011;
        check("SLT -1 < 1", 32'd1, 1'b0);

        // SLT: 1 < -1 (signed) => false
        i_operand_a = 32'd1; i_operand_b = 32'hFFFF_FFFF; i_ALUCtrl = 4'b0011;
        check("SLT 1 < -1 false", 32'd0, 1'b1);

        // SLTU: 0xFFFFFFFF > 1 unsigned => sltu = 0
        i_operand_a = 32'hFFFF_FFFF; i_operand_b = 32'd1; i_ALUCtrl = 4'b0100;
        check("SLTU 0xFFFF<1 false", 32'd0, 1'b1);

        // SLTU: 1 < 0xFFFFFFFF unsigned => sltu = 1
        i_operand_a = 32'd1; i_operand_b = 32'hFFFF_FFFF; i_ALUCtrl = 4'b0100;
        check("SLTU 1<0xFFFF true", 32'd1, 1'b0);

        // XOR: 0xF0F0 ^ 0x0F0F = 0xFFFF
        i_operand_a = 32'h0000_F0F0; i_operand_b = 32'h0000_0F0F; i_ALUCtrl = 4'b0101;
        check("XOR", 32'h0000_FFFF, 1'b0);

        // SRL: 0x80000000 >> 1 = 0x40000000 (logical, no sign extension)
        i_operand_a = 32'h8000_0000; i_operand_b = 32'd1; i_ALUCtrl = 4'b0110;
        check("SRL 0x80000000>>1", 32'h4000_0000, 1'b0);

        // SRL: shift by 31
        i_operand_a = 32'h8000_0000; i_operand_b = 32'd31; i_ALUCtrl = 4'b0110;
        check("SRL shift 31", 32'd1, 1'b0);

        // SRA: 0x80000000 >>> 1 = 0xC0000000 (arithmetic, sign-extends)
        i_operand_a = 32'h8000_0000; i_operand_b = 32'd1; i_ALUCtrl = 4'b0111;
        check("SRA 0x80000000>>>1", 32'hC000_0000, 1'b0);

        // SRA: -8 >>> 2 = -2
        i_operand_a = 32'hFFFF_FFF8; i_operand_b = 32'd2; i_ALUCtrl = 4'b0111;
        check("SRA -8>>>2", 32'hFFFF_FFFE, 1'b0);

        // OR: 0xA0 | 0x0F = 0xAF
        i_operand_a = 32'h0000_00A0; i_operand_b = 32'h0000_000F; i_ALUCtrl = 4'b1000;
        check("OR", 32'h0000_00AF, 1'b0);

        // AND: 0xFF & 0x0F = 0x0F
        i_operand_a = 32'h0000_00FF; i_operand_b = 32'h0000_000F; i_ALUCtrl = 4'b1001;
        check("AND", 32'h0000_000F, 1'b0);

        $display("---");
        if (fail_count == 0)
            $display("ALL TESTS PASSED (%0d/%0d)", pass_count, pass_count + fail_count);
        else
            $display("FAILED %0d/%0d tests", fail_count, pass_count + fail_count);
        $finish;
    end

endmodule
