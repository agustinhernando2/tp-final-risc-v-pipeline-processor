`timescale 1ns / 1ps

// Integration test: Branch & Jump handling (Stage 8).
//
// Test 1 — BNE loop: counts x1 from 0 to 3, exit writes x3=99.
// Test 2 — JAL: jump skips one instruction, checks x5 and return address in x1.
module tb_branch;

    localparam NB_PC = 32;
    localparam NB_INST = 32;
    localparam NB_REG = 5;
    localparam DATA_WIDTH = 32;
    localparam NB_ADDR = 8;

    logic               i_clk;
    logic               i_reset;
    logic               i_if_enable;
    logic               i_imem_wr;
    logic [NB_ADDR-1:0] i_imem_addr;
    logic [NB_INST-1:0] i_imem_data;

    RISCV #(
        .NB_PC     (NB_PC),
        .NB_INST   (NB_INST),
        .NB_REG    (NB_REG),
        .DATA_WIDTH(DATA_WIDTH),
        .NB_ADDR   (NB_ADDR)
    ) DUT (
        .i_clk         (i_clk),
        .i_reset       (i_reset),
        .i_if_enable   (i_if_enable),
        .i_imem_wr     (i_imem_wr),
        .i_imem_addr   (i_imem_addr),
        .i_imem_data   (i_imem_data),
        // debug/status ports unused in this integration test
        .o_PC          (),
        .o_halt        (),
        .i_dbg_reg_addr('0),
        .o_dbg_reg_data(),
        .i_dbg_mem_addr('0),
        .o_dbg_mem_data()
    );

    initial i_clk = 0;
    always #5 i_clk = ~i_clk;

    task tick;
        @(posedge i_clk);
        #1;
    endtask

    task load_instr(input [NB_ADDR-1:0] addr, input [NB_INST-1:0] instr);
        @(negedge i_clk);
        i_imem_wr   = 1;
        i_imem_addr = addr;
        i_imem_data = instr;
        @(posedge i_clk);
        #1;
        i_imem_wr = 0;
    endtask

    int pass_count;
    int fail_count;

    task check(input string name, input logic [DATA_WIDTH-1:0] got,
               input logic [DATA_WIDTH-1:0] expected);
        if (got === expected) begin
            $display("  PASS  %s: 0x%08h", name, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s: got 0x%08h, expected 0x%08h", name, got, expected);
            fail_count++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Pre-assembled instruction constants
    // -------------------------------------------------------------------------
    // ADDI rd, rs1, imm → {imm[11:0], rs1, 000, rd, 0010011}
    localparam [NB_INST-1:0] ADDI_X1_X0_0 = 32'h00000093;  // addi x1, x0, 0
    localparam [NB_INST-1:0] ADDI_X2_X0_3 = 32'h00300113;  // addi x2, x0, 3
    localparam [NB_INST-1:0] ADDI_X1_X1_1 = 32'h00108093;  // addi x1, x1, 1
    localparam [NB_INST-1:0] ADDI_X3_X0_99 = 32'h06300193;  // addi x3, x0, 99

    // BNE x1, x2, -4 bytes (= -1 word = back to previous instruction)
    // B-type: {imm[12], imm[10:5], rs2=x2, rs1=x1, funct3=001, imm[4:1], imm[11], opcode}
    // imm=-4: [12]=1,[11]=1,[10:5]=111111,[4:1]=1110
    // = 1_111111_00010_00001_001_1110_1_1100011 = 0xFE209EE3
    localparam [NB_INST-1:0] BNE_X1_X2_M1 = 32'hFE209EE3;  // bne x1, x2, -4 bytes

    localparam [NB_INST-1:0] ADDI_X5_X0_1 = 32'h00100293;  // addi x5, x0, 1
    localparam [NB_INST-1:0] ADDI_X5_X0_2 = 32'h00200293;  // addi x5, x0, 2
    localparam [NB_INST-1:0] ADDI_X4_X0_77 = 32'h04D00213;  // addi x4, x0, 77

    // JAL x1, +8 bytes (= +2 words = skip next instruction)
    // J-type: {imm[20], imm[10:1], imm[11], imm[19:12], rd=x1, opcode}
    // imm=+8: [20]=0,[19:12]=0,[11]=0,[10:1]=0000001000
    // = 0_0000001000_0_00000000_00001_1101111 = 0x00800067? No...
    // Bits: [31]=imm[20]=0, [30:21]=imm[10:1]=0000001000, [20]=imm[11]=0,
    //       [19:12]=imm[19:12]=0, [11:7]=rd=00001, [6:0]=1101111
    // Hex nibbles:
    //   31-28: 0000 = 0
    //   27-24: 0100 = 4  (bits 30:28=001, bit 27:24=0000... wait)
    // Let me compute: bit30=0,29=0,28=0,27=0,26=0,25=1,24=0
    //                 bits[30:21] = 0000001000 → bit30=0,29=0,28=0,27=0,26=0,25=1,24=0,23=0,22=0,21=0
    // 31:0 = 0 0000001000 0 00000000 00001 1101111
    //      = 0000_0001_0000_0000_0000_1000_0110_1111? No.
    // Let me group properly:
    //   bit 31 = 0
    //   bits 30-21 = 0000001000
    //   bit 20 = 0
    //   bits 19-12 = 00000000
    //   bits 11-7 = 00001
    //   bits 6-0 = 1101111
    //
    // Hex: 31-28=0b0000=0x0, 27-24=0b0001=0x0 wait
    // bit31=0, bit30=0, bit29=0, bit28=0 → nibble[31:28]=0x0
    // bit27=0, bit26=0, bit25=1, bit24=0 → nibble[27:24]=0x2? no, 0b0010=2?
    //   26=0,25=1,24=0 → bit27=0,bit26=0,bit25=1,bit24=0 = 0010 = 2? no, 0*8+0*4+1*2+0*1=2
    //   Wait: bit27=0(MSB), bit26=0, bit25=1, bit24=0(LSB) = 0b0010 = 2?
    //   No: 0*8 + 0*4 + 1*2 + 0*1 = 2. But in hex that nibble = 2. But wait it's bit27-bit24 which is 0010 = 2.
    //   Oh but bits 30:21 are 0000001000. bits 30,29,28 = 000, then 27,26,25,24 = 0001? No.
    //   Bit numbering: 0000001000 spans bits [30:21].
    //   bit30=0, bit29=0, bit28=0, bit27=0, bit26=0, bit25=1, bit24=0, bit23=0, bit22=0, bit21=0
    // So:
    //   bit31=0, bit30=0, bit29=0, bit28=0 → 0x0
    //   bit27=0, bit26=0, bit25=1, bit24=0 → 0x2? 0b0010=2?
    //   Hmm: 0*2^3 + 0*2^2 + 1*2^1 + 0*2^0 = 2. In hex = 0x2. So nibble [27:24] = 0x2.
    //   Actually wait, bit27 is the most significant of this nibble. bit27=0, bit26=0, bit25=1, bit24=0
    //   As a 4-bit number with bit27 as MSB: 0*8 + 0*4 + 1*2 + 0*1 = 2. Nibble = 0x2.
    //   bit23=0, bit22=0, bit21=0, bit20=0 → 0x0
    //   bit19=0, bit18=0, bit17=0, bit16=0 → 0x0
    //   bit15=0, bit14=0, bit13=0, bit12=0 → 0x0
    //   bit11=0, bit10=0, bit9=0, bit8=0 → 0x0? wait bits 11-7 = 00001
    //   bit11=0, bit10=0, bit9=0, bit8=0 → 0x0
    //   bit7=1, bit6=0, bit5=1, bit4=0 → wait bits 6-0 = 1101111
    //   bit6=1, bit5=1, bit4=0, bit3=1, bit2=1, bit1=1, bit0=1
    //   bit7=0? No, bit7 is part of rd[11:7] which is 00001, so bit7=0, bit8=0, bit9=0, bit10=0, bit11=0
    //   So rd (bits 11:7) = 00001 → bit11=0, bit10=0, bit9=0, bit8=0, bit7=1
    //   Nibble [11:8] = 0b0000 = 0
    //   bit7=1, bit6=1, bit5=1, bit4=0 → 0b1110 = E?
    //   wait opcode 1101111 = bit6=1, bit5=1, bit4=0, bit3=1, bit2=1, bit1=1, bit0=1
    //   bit7=1 (rd[0]), bit6=1, bit5=1, bit4=0 → nibble = 0b1110 = E
    //   bit3=1, bit2=1, bit1=1, bit0=1 → nibble = 0xF
    //
    // Full hex: 0x0020_0000_086F? No let me just compute it directly:
    // Binary: 0000_0000_0100_0000_0000_1000_0110_1111
    // Hmm that doesn't look right either. Let me try a different approach.
    //
    // Actually, I'm going to use a known reference encoding.
    // jal x1, 8 means branch to PC+8 bytes.
    // Standard encoding: looking at a reference table,
    // jal rd, offset = {imm[20|10:1|11|19:12], rd, 1101111}
    // For offset=8: imm = 8, binary = 0b00000000000000001000
    // [20]=0, [19:12]=00000000, [11]=0, [10:1]=0000001000
    //
    // Instruction: {[20], [10:1], [11], [19:12], rd, opcode}
    //            = {0, 0000001000, 0, 00000000, 00001, 1101111}
    //
    // Let me assemble bit by bit:
    // Position [31] = imm[20] = 0
    // Positions [30:21] = imm[10:1] = 0000001000
    // Position [20] = imm[11] = 0
    // Positions [19:12] = imm[19:12] = 00000000
    // Positions [11:7] = rd = 00001
    // Positions [6:0] = opcode = 1101111
    //
    // In 32-bit binary from bit 31 to bit 0:
    // 0 | 0000001000 | 0 | 00000000 | 00001 | 1101111
    // Grouping into nibbles:
    // [31:28] = 0_000 = 0000 = 0x0
    // [27:24] = 0010 = 0x2?
    //   Bit 30=0,29=0,28=0 then bit27=0, so [31:28] = 0000.
    //   Then [27:24]: bit27=0, bit26=0, bit25=1, bit24=0 → 0010 = 0x2?
    //   wait: 0b0010 = 2, but in a nibble with MSB first: 0,0,1,0 = 0x2. Yes.
    //   Hmm, wait. If [30:21] = 0000001000, then:
    //   bit30=0, bit29=0, bit28=0, bit27=0, bit26=0, bit25=1, bit24=0, bit23=0, bit22=0, bit21=0
    //   So [27:24] = bit27,bit26,bit25,bit24 = 0,0,1,0 = 0x2
    // [23:20] = bit23,22,21,20 = 0,0,0,0 = 0x0
    // [19:16] = bit19,18,17,16 = 0,0,0,0 = 0x0
    // [15:12] = bit15,14,13,12 = 0,0,0,0 = 0x0
    // [11:8] = bit11,10,9,8 = 0,0,0,0 = 0x0
    // [7:4] = bit7,6,5,4 = 0+opcode bits
    //   bit7 = rd bit0 = 1 (rd=00001, so bit7=1)
    //   bit6 = opcode bit6 = 1 (opcode=1101111)
    //   bit5 = opcode bit5 = 1
    //   bit4 = opcode bit4 = 0
    //   → [7:4] = 1,1,1,0 = 0xE
    // [3:0] = opcode bits 3:0 = 1,1,1,1 = 0xF
    //
    // Result: 0x00200_00_0_0E_F = 0x0020_0086_F?
    // Full: 0x00200_0086F? Let me write it out: 0x00_20_00_00_08_6F?
    // I'm making arithmetic errors. Let me just compute the integer value directly.
    //
    // Total value:
    // bit31=0: 0
    // bit30=0: 0
    // bit29=0: 0
    // bit28=0: 0
    // bit27=0: 0
    // bit26=0: 0
    // bit25=1: 2^25 = 33554432 = 0x02000000
    // bit24=0: 0
    // ...all other imm bits = 0...
    // bit11=0: 0
    // bit10=0: 0
    // bit9=0: 0
    // bit8=0: 0
    // bit7=1: 2^7 = 128 = 0x80 (rd bit0 = 1)
    // bit6=1: 2^6 = 64 = 0x40 (opcode bit6)
    // bit5=1: 2^5 = 32 = 0x20 (opcode bit5)
    // bit4=0: 0
    // bit3=1: 2^3 = 8
    // bit2=1: 2^2 = 4
    // bit1=1: 2^1 = 2
    // bit0=1: 2^0 = 1
    //
    // Total = 0x02000000 + 0x80 + 0x40 + 0x20 + 8 + 4 + 2 + 1
    //       = 0x02000000 + 0xEF
    //       = 0x020000EF
    //
    // So JAL x1, +8 = 0x020000EF? That looks wrong. Let me verify with a known tool.
    //
    // Actually the standard `jal x1, 8` encoding should be:
    // Looking at RISC-V Card: rd=x1=1=0b00001, opcode=0x6F
    // imm=8=0b01000
    // J-format: inst[31]=imm[20], inst[30:21]=imm[10:1], inst[20]=imm[11], inst[19:12]=imm[19:12], inst[11:7]=rd, inst[6:0]=opcode
    // imm=8 binary (20 bits): 00000000000000001000
    // imm[20]=0, imm[19:12]=00000000, imm[11]=0, imm[10:1]=0000001000 (actually for 8: bit3=1, so imm[10:1]=0000001000? No.)
    // 8 in 20-bit binary: 00000000000000001000
    // Position: [20,19,18,...,4,3,2,1,0] → wait, the bit positions in the imm are:
    // imm[20] = 0
    // imm[19:12] = 0000 0000
    // imm[11] = 0
    // imm[10:1] = 00 0000 1000
    //             ^bit10       ^bit1
    // Actually for 8: 8 = 0b1000. In 20-bit: bits [3]=1, all others 0.
    // imm[20]=0, imm[19]=0,..., imm[4]=0, imm[3]=1, imm[2]=0, imm[1]=0
    // So imm[10:1] = {0,0,0,0,0,0,0,1,0,0} (bit10 to bit1 of 8)
    // Wait, imm[1]=0 (bit1 of 8), imm[2]=0, imm[3]=1 (bit3 of 8). So imm[10:1] = 0000001000? No.
    // imm[10:1] = {imm[10], imm[9], ..., imm[1]}
    //           = {0,0,0,0,0,0,1,0,0,0}... wait 8=0b1000, so bit3=1.
    //           imm[1]=0, imm[2]=0, imm[3]=1, imm[4-10]=0
    //           So imm[10:1] = 0000001000
    //
    // So bit25=1 is correct (imm[10:1] has bit [25] = imm[3]=1 since inst[25]=imm[3])
    // Wait: inst[30:21] = imm[10:1], so:
    //   inst[30] = imm[10] = 0
    //   inst[29] = imm[9] = 0
    //   inst[28] = imm[8] = 0
    //   inst[27] = imm[7] = 0
    //   inst[26] = imm[6] = 0
    //   inst[25] = imm[5] = 0
    //   inst[24] = imm[4] = 0
    //   inst[23] = imm[3] = 1 ← bit3 of 8 is 1!
    //   inst[22] = imm[2] = 0
    //   inst[21] = imm[1] = 0
    //
    // Oh wait! I had it wrong. imm[3] corresponds to instruction bit 23, not bit 25!
    // So bit25=imm[5]=0, and bit23=imm[3]=1.
    //
    // Let me redo:
    // inst[30:21] = imm[10:1]
    //   inst[30] = imm[10] = 0
    //   inst[29] = imm[9]  = 0
    //   inst[28] = imm[8]  = 0
    //   inst[27] = imm[7]  = 0
    //   inst[26] = imm[6]  = 0
    //   inst[25] = imm[5]  = 0
    //   inst[24] = imm[4]  = 0
    //   inst[23] = imm[3]  = 1 ← key!
    //   inst[22] = imm[2]  = 0
    //   inst[21] = imm[1]  = 0
    //
    // So for jal x1, +8:
    // inst[31] = 0
    // inst[30:21] = {0,0,0,0,0,0,0,1,0,0}
    // inst[20] = 0
    // inst[19:12] = 00000000
    // inst[11:7] = 00001 (rd=x1)
    // inst[6:0] = 1101111 (opcode=0x6F)
    //
    // Value:
    // inst[23] = 1 → 2^23 = 8388608 = 0x800000
    // inst[7] = 1 → 2^7 = 128 = 0x80  (rd bit 0)
    // inst[6:4] = 110 → 0x60+0x40+0x20? → 0x60? No.
    //   inst[6]=1: 0x40, inst[5]=1: 0x20, inst[4]=0
    // inst[3:0] = 1111 → 0xF
    //
    // Total = 0x800000 + 0x80 + 0x40 + 0x20 + 0xF
    //       = 0x800000 + 0xEF
    //       = 0x8000EF
    //
    // So jal x1, +8 = 0x008000EF
    //
    // That means the 32-bit encoding is 0x008000EF.
    //
    // Actually let me double-check with a reference. Looking at it from a different angle:
    // jal x1, 0 (no offset) → {0, 00000000000, 0, 00000000, 00001, 1101111}
    //   = 0x000000EF
    //
    // jal x1, 4 (offset 4 bytes = 1 instruction forward) → imm=4, imm[2]=1
    //   inst[22]=imm[2]=1 → 2^22 = 0x400000
    //   = 0x400000 + 0xEF = 0x4000EF
    //
    // jal x1, 8 (offset 8 bytes = 2 instructions forward) → imm=8, imm[3]=1
    //   inst[23]=imm[3]=1 → 2^23 = 0x800000
    //   = 0x800000 + 0xEF = 0x8000EF
    //
    // So JAL x1, +8 = 0x008000EF ✓
    //
    // Now we can verify our branch_target computation:
    // J-imm from ImmediateExtend for this instruction:
    // {11{inst[31]}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}
    // = {11{0}, 0, 00000000, 0, 0000001000, 0}
    //   Wait, inst[30:21] = 0000001000 (for offset 8), but I said inst[23]=1 not inst[25].
    //   Hmm, inst[30:21] is {inst[30],inst[29],...,inst[21]} and for jal x1,8 we have inst[23]=1.
    //   So inst[30:21] = {0,0,0,0,0,0,0,1,0,0} (7 zeros, then 1, then 2 zeros)
    //   = 0b0000001000... wait I'm confusing myself. 10 bits: inst[30]=0,inst[29]=0,...,inst[23]=1,inst[22]=0,inst[21]=0
    //   These map to imm[10:1]: imm[10]=inst[30]=0, ..., imm[3]=inst[23]=1, imm[2]=inst[22]=0, imm[1]=inst[21]=0
    //   So imm[3]=1, all other imm bits=0.
    //
    // ImmediateExtend for J-type:
    // {11{inst[31]}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}
    // = {11{0}, 0, 00000000, 0, 0000001000, 0}
    // Wait, the 10-bit field inst[30:21] is 0000001000 only if imm[3]=1 → inst[23]=1.
    // But inst[30:21] maps to imm[10:1], and the bit imm[3]=1 maps to inst[23] which is bit position 7 of the 10-bit field (counting from 0 on the right): inst[30]=imm[10], ..., inst[23]=imm[3].
    // So inst[30:21] as a 10-bit value = 0b0000001000 (bit 2 from right = 1, since imm[3] = bit at position 3 in the imm, and within inst[30:21] it's at position 23-21=2 from bit21).
    // Wait: bit23 is bit (23-21)=2 of the 10-bit field (counting from bit21=0). So inst[30:21] bit 2 = 1. As a 10-bit number from inst[30] (MSB) to inst[21] (LSB): 0b0000001000 = decimal 8.
    //
    // OK so ImmediateExtend output for jal x1, +8:
    // {11'b0, 0, 8'b0, 0, 10'b0000001000, 1'b0}
    // = {11'b0, 1, 18'b0, 0}... no.
    // Let me just track which bits are 1:
    // The 32-bit immediate has: imm[3]=1, all others 0.
    // So output = 32'h00000008 = 8.
    //
    // branch_target = PC + imm = 0 + 8 = byte 8 = instruction word 2 (PC>>2).
    // If the jal is at PC=0, branch_target = 8. That means it jumps to instruction 2. ✓

    localparam [NB_INST-1:0] JAL_X1_P8 = 32'h008000EF;  // jal x1, +8 bytes (= skip 1 instruction)
    localparam [NB_INST-1:0] NOP = 32'h00000013;  // addi x0, x0, 0

    // -------------------------------------------------------------------------
    // Main
    // -------------------------------------------------------------------------
    initial begin
        pass_count  = 0;
        fail_count  = 0;
        i_imem_wr   = 0;
        i_imem_addr = '0;
        i_imem_data = '0;

        // ==============================================================
        // TEST 1: BNE Loop — count x1 from 0 to 3
        // Program:
        //   0: addi x1, x0, 0    # x1 = 0
        //   1: addi x2, x0, 3    # x2 = 3
        //   2: addi x1, x1, 1    # x1++
        //   3: bne  x1, x2, -4   # back to PC 2 if x1 != x2
        //   4: addi x3, x0, 99   # x3 = 99 (only after loop exits)
        //
        // BNE -4 bytes: target = PC(byte 12) + (-4) = byte 8 = instruction 2. ✓
        // ==============================================================
        $display("--- BNE Loop Test ---");

        i_reset     = 1;
        i_if_enable = 0;
        @(posedge i_clk);
        #1;
        @(posedge i_clk);
        #1;
        i_reset = 0;

        load_instr(8'h00, ADDI_X1_X0_0);
        load_instr(8'h01, ADDI_X2_X0_3);
        load_instr(8'h02, ADDI_X1_X1_1);
        load_instr(8'h03, BNE_X1_X2_M1);
        load_instr(8'h04, ADDI_X3_X0_99);

        i_if_enable = 1;
        repeat (80) tick;

        check("BNE: x1 == 3", DUT.ID.RF.r_RF[1], 32'd3);
        check("BNE: x2 == 3", DUT.ID.RF.r_RF[2], 32'd3);
        check("BNE: x3 == 99", DUT.ID.RF.r_RF[3], 32'd99);

        // ==============================================================
        // TEST 2: JAL — skip one instruction, check target and fallthrough
        // Program:
        //   0: jal x1, +8    # jump to instr 2; x1 = 4 (= PC+4)
        //   1: addi x5, x0, 1   # skipped
        //   2: addi x5, x0, 2   # x5 = 2
        //   3: addi x4, x0, 77  # x4 = 77 (continues normally)
        //
        // JAL +8 bytes = +2 instructions. target = PC(0)+8 = byte 8 = instruction 2. ✓
        // Return address x1 = PC+4 = 0+4 = 4.
        // ==============================================================
        $display("\n--- JAL Test ---");

        i_if_enable = 0;
        i_reset     = 1;
        @(posedge i_clk);
        #1;
        @(posedge i_clk);
        #1;
        i_reset = 0;

        load_instr(8'h00, JAL_X1_P8);
        load_instr(8'h01, ADDI_X5_X0_1);
        load_instr(8'h02, ADDI_X5_X0_2);
        load_instr(8'h03, ADDI_X4_X0_77);

        i_if_enable = 1;
        repeat (50) tick;

        check("JAL: x1 == 4 (return addr)", DUT.ID.RF.r_RF[1], 32'd4);
        check("JAL: x5 == 2 (not skipped)", DUT.ID.RF.r_RF[5], 32'd2);
        check("JAL: x4 == 77", DUT.ID.RF.r_RF[4], 32'd77);

        // ==============================================================
        // TEST 3: Taken branch flushes the instruction right behind it (B+4)
        // Regression for BUG-002: branch resolves in MEM, so when taken the
        // instruction in EX (B+4) must be flushed too. Earlier it leaked and
        // committed its write-back.
        // Program:
        //   0: addi x1,  x0, 5
        //   1: addi x2,  x0, 5
        //   2: beq  x1, x2, +12   # taken (5==5); target = byte 8 + 12 = byte 20 = instr 5
        //   3: addi x10, x0, 123  # B+4 -> must be flushed (target jumps over it)
        //   4: addi x11, x0, 200  # B+8 -> flushed
        //   5: addi x12, x0, 77   # branch target
        //
        // x10 must stay 0: the target does not overwrite it, so a non-zero x10
        // proves the post-branch instruction leaked.
        // ==============================================================
        $display("\n--- Taken-branch flush (B+4) Test ---");

        i_if_enable = 0;
        i_reset     = 1;
        @(posedge i_clk);
        #1;
        @(posedge i_clk);
        #1;
        i_reset = 0;

        load_instr(8'h00, 32'h00500093);  // addi x1,  x0, 5
        load_instr(8'h01, 32'h00500113);  // addi x2,  x0, 5
        load_instr(8'h02, 32'h00208663);  // beq  x1, x2, +12
        load_instr(8'h03, 32'h07B00513);  // addi x10, x0, 123 (B+4)
        load_instr(8'h04, 32'h0C800593);  // addi x11, x0, 200 (B+8)
        load_instr(8'h05, 32'h04D00613);  // addi x12, x0, 77  (target)

        i_if_enable = 1;
        repeat (40) tick;

        check("FLUSH: x10 == 0 (B+4 flushed)", DUT.ID.RF.r_RF[10], 32'd0);
        check("FLUSH: x11 == 0 (B+8 flushed)", DUT.ID.RF.r_RF[11], 32'd0);
        check("FLUSH: x12 == 77 (target ran)", DUT.ID.RF.r_RF[12], 32'd77);

        // ==============================================================
        // Summary
        // ==============================================================
        $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
