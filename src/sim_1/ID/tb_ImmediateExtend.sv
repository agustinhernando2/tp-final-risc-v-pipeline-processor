`timescale 1ns / 1ps

module tb_ImmediateExtend;

    localparam DATA_WIDTH = 32;

    logic [DATA_WIDTH-1:0] instruction;
    logic [           2:0] imm_src;
    logic [DATA_WIDTH-1:0] immediate;

    int                    pass_count;
    int                    fail_count;

    ImmediateExtend #(
        .DATA_WIDTH(DATA_WIDTH)
    ) DUT (
        .i_instruction(instruction),
        .i_ImmSrc     (imm_src),
        .o_immediate  (immediate)
    );

    task automatic check(input string label, input logic [DATA_WIDTH-1:0] got, expected);
        if (got === expected) begin
            $display("  PASS  %s: 0x%08h", label, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s: expected 0x%08h, got 0x%08h", label, expected, got);
            fail_count++;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;

        // ----------------------------------------------------------------
        // I-type: ADDI x1, x0, -1  → inst[31:20] = 12'hFFF → imm = -1
        // opcode=0010011 funct3=000 rs1=00000 rd=00001 imm=111111111111
        // 31:20=FFF  19:15=00000  14:12=000  11:7=00001  6:0=0010011
        // ----------------------------------------------------------------
        $display("--- I-type ---");
        instruction = 32'hFFF0_0093;  // addi x1, x0, -1
        imm_src     = 3'b000;
        #1;
        check("addi x1,x0,-1 → -1", immediate, 32'hFFFF_FFFF);

        instruction = 32'h0050_0093;  // addi x1, x0, 5
        imm_src     = 3'b000;
        #1;
        check("addi x1,x0,5  → 5", immediate, 32'h0000_0005);

        // ----------------------------------------------------------------
        // S-type: SW x2, -4(x1)
        // imm[11:5]=inst[31:25]=1111111  imm[4:0]=inst[11:7]=11100
        // full 12-bit imm = 1111_1111_1100 = -4
        // opcode=0100011 funct3=010 rs1=00001 rs2=00010
        // inst = 1111111_00010_00001_010_11100_0100011
        // ----------------------------------------------------------------
        $display("--- S-type ---");
        instruction = 32'hFE20_AE23;  // sw x2, -4(x1)
        imm_src     = 3'b001;
        #1;
        check("sw x2,-4(x1) → -4", immediate, 32'hFFFF_FFFC);

        // SW x3, 8(x1): imm=8=0000_0000_1000 → inst[31:25]=0000000, inst[11:7]=01000
        // inst = 0000000_00011_00001_010_01000_0100011
        instruction = 32'h0030_A423;  // sw x3, 8(x1)
        imm_src     = 3'b001;
        #1;
        check("sw x3,8(x1)  → 8", immediate, 32'h0000_0008);

        // ----------------------------------------------------------------
        // B-type: BEQ x1, x2, +8
        // imm = 13-bit {inst[31],inst[7],inst[30:25],inst[11:8], 1'b0} = 8
        // 8 → 0000000001000 (13 bits)
        //   inst[31]=0, inst[7]=0, inst[30:25]=000000, inst[11:8]=0100
        // opcode=1100011 funct3=000 rs1=00001 rs2=00010
        // inst = 0_000000_00010_00001_000_0100_0_1100011
        // ----------------------------------------------------------------
        $display("--- B-type ---");
        instruction = 32'h0020_8463;  // beq x1, x2, +8
        imm_src     = 3'b010;
        #1;
        check("beq +8 → 8", immediate, 32'h0000_0008);

        // BNE x1, x2, -4: imm=-4 → 1111111111100 (13-bit signed)
        //   inst[31]=1, inst[7]=1, inst[30:25]=111111, inst[11:8]=1110
        // inst = 1_111111_00010_00001_001_1110_1_1100011
        instruction = 32'hFE20_9EE3;  // bne x1, x2, -4
        imm_src     = 3'b010;
        #1;
        check("bne -4  → -4", immediate, 32'hFFFF_FFFC);

        // ----------------------------------------------------------------
        // U-type: LUI x1, 0x12345  → imm = 0x12345000
        // opcode=0110111 rd=00001
        // inst = 00010010001101000101_00001_0110111
        // ----------------------------------------------------------------
        $display("--- U-type ---");
        instruction = 32'h1234_50B7;  // lui x1, 0x12345
        imm_src     = 3'b011;
        #1;
        check("lui 0x12345 → 0x12345000", immediate, 32'h1234_5000);

        // LUI x1, 0xFFFFF → imm = 0xFFFFF000
        instruction = 32'hFFFF_F0B7;
        imm_src     = 3'b011;
        #1;
        check("lui 0xFFFFF → 0xFFFFF000", immediate, 32'hFFFF_F000);

        // ----------------------------------------------------------------
        // J-type: JAL x1, +4
        // imm=4 → 21-bit {inst[31],inst[19:12],inst[20],inst[30:21],1'b0}
        //   4 = 00000000000000000100
        //   inst[31]=0 inst[19:12]=00000000 inst[20]=0 inst[30:21]=0000000010
        // opcode=1101111 rd=00001
        // inst = 0_0000000010_0_00000000_00001_1101111
        // ----------------------------------------------------------------
        $display("--- J-type ---");
        instruction = 32'h0040_00EF;  // jal x1, +4
        imm_src     = 3'b100;
        #1;
        check("jal +4  → 4", immediate, 32'h0000_0004);

        // JAL x0, -8: imm=-8
        // -8 = 1111111111111111111000 (21-bit)
        //   inst[31]=1 inst[19:12]=11111111 inst[20]=1 inst[30:21]=1111111100
        // inst = 1_1111111100_1_11111111_00000_1101111
        instruction = 32'hFF9F_F06F;  // jal x0, -8
        imm_src     = 3'b100;
        #1;
        check("jal -8  → -8", immediate, 32'hFFFF_FFF8);

        $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
