`timescale 1ns / 1ps

module tb_ExecuteStage;

    parameter DATA_WIDTH = 32;
    parameter NB_REG = 5;
    parameter ALU_CTRL_WIDTH = 4;

    logic [DATA_WIDTH-1:0] i_read_data_1;
    logic [DATA_WIDTH-1:0] i_read_data_2;
    logic [DATA_WIDTH-1:0] i_immediate;
    logic [    NB_REG-1:0] i_rd;
    logic [           2:0] i_funct3;
    logic                  i_funct7_5;
    logic                  i_ALUSrc;
    logic [           1:0] i_ALUOp;
    logic [DATA_WIDTH-1:0] o_alu_result;
    logic                  o_zero;
    logic [DATA_WIDTH-1:0] o_read_data_2;
    logic [    NB_REG-1:0] o_rd;

    // Forwarding tied off: no forwarding in this unit test
    ExecuteStage #(
        .DATA_WIDTH(DATA_WIDTH),
        .NB_REG(NB_REG),
        .ALU_CTRL_WIDTH(ALU_CTRL_WIDTH)
    ) dut (
        .i_read_data_1      (i_read_data_1),
        .i_read_data_2      (i_read_data_2),
        .i_immediate        (i_immediate),
        .i_rd               (i_rd),
        .i_funct3           (i_funct3),
        .i_funct7_5         (i_funct7_5),
        .i_ALUSrc           (i_ALUSrc),
        .i_ALUOp            (i_ALUOp),
        .i_ForwardA         (2'b00),
        .i_ForwardB         (2'b00),
        .i_ex_mem_alu_result('0),
        .i_wb_write_data    ('0),
        .o_alu_result       (o_alu_result),
        .o_zero             (o_zero),
        .o_read_data_2      (o_read_data_2),
        .o_rd               (o_rd)
    );

    integer pass_count = 0;
    integer fail_count = 0;

    task automatic check(input string name, input logic [DATA_WIDTH-1:0] exp_result,
                         input logic exp_zero);
        #1;
        if (o_alu_result !== exp_result || o_zero !== exp_zero) begin
            $display("FAIL [%s]: result=%0d (exp %0d), zero=%b (exp %b)", name,
                     $signed(o_alu_result), $signed(exp_result), o_zero, exp_zero);
            fail_count++;
        end else begin
            $display("PASS [%s]", name);
            pass_count++;
        end
    endtask

    initial begin
        i_rd = 5'd1;

        // R-type ADD: x1=10, x2=3 => 13
        i_read_data_1 = 32'd10;
        i_read_data_2 = 32'd3;
        i_immediate = 32'd0;
        i_funct3 = 3'b000;
        i_funct7_5 = 1'b0;
        i_ALUSrc = 1'b0;
        i_ALUOp = 2'b10;
        check("R-type ADD", 32'd13, 1'b0);

        // R-type SUB: 10 - 3 = 7
        i_funct7_5 = 1'b1;
        check("R-type SUB", 32'd7, 1'b0);

        // R-type AND: 0xFF & 0x0F = 0x0F
        i_read_data_1 = 32'h0000_00FF;
        i_read_data_2 = 32'h0000_000F;
        i_funct3 = 3'b111;
        i_funct7_5 = 1'b0;
        check("R-type AND", 32'h0000_000F, 1'b0);

        // R-type OR
        i_read_data_1 = 32'h0000_00A0;
        i_read_data_2 = 32'h0000_000F;
        i_funct3 = 3'b110;
        check("R-type OR", 32'h0000_00AF, 1'b0);

        // R-type SLT: -1 < 5 => 1
        i_read_data_1 = 32'hFFFF_FFFF;
        i_read_data_2 = 32'd5;
        i_funct3 = 3'b010;
        check("R-type SLT", 32'd1, 1'b0);

        // I-type ADDI: rs1=20, imm=5 => 25 (ALUSrc=1)
        i_read_data_1 = 32'd20;
        i_read_data_2 = 32'd0;
        i_immediate = 32'd5;
        i_funct3 = 3'b000;
        i_funct7_5 = 1'b0;
        i_ALUSrc = 1'b1;
        i_ALUOp = 2'b11;
        check("I-type ADDI", 32'd25, 1'b0);

        // I-type XORI: 0xF0 ^ 0xFF = 0x0F
        i_read_data_1 = 32'h0000_00F0;
        i_immediate = 32'h0000_00FF;
        i_funct3 = 3'b100;
        check("I-type XORI", 32'h0000_000F, 1'b0);

        // I-type SRLI: 0x80000000 >> 1
        i_read_data_1 = 32'h8000_0000;
        i_immediate = 32'd1;
        i_funct3 = 3'b101;
        i_funct7_5 = 1'b0;
        check("I-type SRLI", 32'h4000_0000, 1'b0);

        // I-type SRAI: 0x80000000 >>> 1
        i_funct7_5 = 1'b1;
        check("I-type SRAI", 32'hC000_0000, 1'b0);

        // Load/Store (ALUOp=00): forced ADD for address: base=100, imm=8 => 108
        i_read_data_1 = 32'd100;
        i_immediate = 32'd8;
        i_ALUSrc = 1'b1;
        i_ALUOp = 2'b00;
        i_funct3 = 3'b010;
        i_funct7_5 = 1'b0;
        check("Load addr ADD", 32'd108, 1'b0);

        // Branch (ALUOp=01): forced SUB: equal values => zero=1
        i_read_data_1 = 32'd42;
        i_read_data_2 = 32'd42;
        i_ALUSrc = 1'b0;
        i_ALUOp = 2'b01;
        check("Branch SUB equal", 32'd0, 1'b1);

        // pass-through: o_read_data_2 and o_rd
        i_read_data_2 = 32'hDEAD_BEEF;
        i_rd = 5'd15;
        #1;
        if (o_read_data_2 !== 32'hDEAD_BEEF || o_rd !== 5'd15) begin
            $display("FAIL [pass-through]");
            fail_count++;
        end else begin
            $display("PASS [pass-through rd/rs2]");
            pass_count++;
        end

        $display("---");
        if (fail_count == 0)
            $display("ALL TESTS PASSED (%0d/%0d)", pass_count, pass_count + fail_count);
        else $display("FAILED %0d/%0d tests", fail_count, pass_count + fail_count);
        $finish;
    end

endmodule
