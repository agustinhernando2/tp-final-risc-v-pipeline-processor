`timescale 1ns / 1ps

module tb_Buffers;

    localparam DATA_WIDTH = 32;
    localparam NB_PC = 32;
    localparam NB_REG = 5;
    localparam CLK_PERIOD = 10;

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------
    logic clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    int pass_count = 0;
    int fail_count = 0;

    task automatic check(input string label, input logic [DATA_WIDTH-1:0] got, expected);
        if (got === expected) begin
            $display("  PASS  %s: 0x%08h", label, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s: expected 0x%08h, got 0x%08h", label, expected, got);
            fail_count++;
        end
    endtask

    task automatic tick();
        @(posedge clk);
        #1;
    endtask

    // ================================================================
    // ID_EX_Buffer
    // ================================================================
    logic id_ex_reset, id_ex_enable, id_ex_flush;
    logic [NB_PC-1:0] id_ex_i_PC;
    logic [DATA_WIDTH-1:0] id_ex_i_rd1, id_ex_i_rd2, id_ex_i_imm;
    logic [NB_REG-1:0] id_ex_i_rs1, id_ex_i_rs2, id_ex_i_rd;
    logic [2:0] id_ex_i_funct3;
    logic       id_ex_i_funct7_5;
    logic id_ex_i_ALUSrc, id_ex_i_RegWrite;
    logic [1:0] id_ex_i_ALUOp;
    logic id_ex_i_MemRead, id_ex_i_MemWrite;
    logic id_ex_i_MemToReg, id_ex_i_Branch, id_ex_i_Jump;

    logic [NB_PC-1:0] id_ex_o_PC;
    logic [DATA_WIDTH-1:0] id_ex_o_rd1, id_ex_o_rd2, id_ex_o_imm;
    logic [NB_REG-1:0] id_ex_o_rs1, id_ex_o_rs2, id_ex_o_rd;
    logic [2:0] id_ex_o_funct3;
    logic       id_ex_o_funct7_5;
    logic id_ex_o_ALUSrc, id_ex_o_RegWrite;
    logic [1:0] id_ex_o_ALUOp;
    logic id_ex_o_MemRead, id_ex_o_MemWrite;
    logic id_ex_o_MemToReg, id_ex_o_Branch, id_ex_o_Jump;

    ID_EX_Buffer #(
        .NB_PC(NB_PC),
        .DATA_WIDTH(DATA_WIDTH),
        .NB_REG(NB_REG)
    ) u_id_ex (
        .i_clk        (clk),
        .i_reset      (id_ex_reset),
        .i_enable     (id_ex_enable),
        .i_flush      (id_ex_flush),
        .i_PC         (id_ex_i_PC),
        .i_read_data_1(id_ex_i_rd1),
        .i_read_data_2(id_ex_i_rd2),
        .i_immediate  (id_ex_i_imm),
        .i_rs1        (id_ex_i_rs1),
        .i_rs2        (id_ex_i_rs2),
        .i_rd         (id_ex_i_rd),
        .i_funct3     (id_ex_i_funct3),
        .i_funct7_5   (id_ex_i_funct7_5),
        .i_ALUSrc     (id_ex_i_ALUSrc),
        .i_ALUOp      (id_ex_i_ALUOp),
        .i_RegWrite   (id_ex_i_RegWrite),
        .i_MemRead    (id_ex_i_MemRead),
        .i_MemWrite   (id_ex_i_MemWrite),
        .i_MemToReg   (id_ex_i_MemToReg),
        .i_Branch     (id_ex_i_Branch),
        .i_Jump       (id_ex_i_Jump),
        .o_PC         (id_ex_o_PC),
        .o_read_data_1(id_ex_o_rd1),
        .o_read_data_2(id_ex_o_rd2),
        .o_immediate  (id_ex_o_imm),
        .o_rs1        (id_ex_o_rs1),
        .o_rs2        (id_ex_o_rs2),
        .o_rd         (id_ex_o_rd),
        .o_funct3     (id_ex_o_funct3),
        .o_funct7_5   (id_ex_o_funct7_5),
        .o_ALUSrc     (id_ex_o_ALUSrc),
        .o_ALUOp      (id_ex_o_ALUOp),
        .o_RegWrite   (id_ex_o_RegWrite),
        .o_MemRead    (id_ex_o_MemRead),
        .o_MemWrite   (id_ex_o_MemWrite),
        .o_MemToReg   (id_ex_o_MemToReg),
        .o_Branch     (id_ex_o_Branch),
        .o_Jump       (id_ex_o_Jump)
    );

    // ================================================================
    // EX_MEM_Buffer
    // ================================================================
    logic ex_mem_reset, ex_mem_enable;
    logic [DATA_WIDTH-1:0] ex_mem_i_alu, ex_mem_i_rd2;
    logic              ex_mem_i_zero;
    logic [NB_REG-1:0] ex_mem_i_rd;
    logic [       2:0] ex_mem_i_funct3;
    logic ex_mem_i_RegWrite, ex_mem_i_MemRead;
    logic ex_mem_i_MemWrite, ex_mem_i_MemToReg;
    logic ex_mem_i_Branch, ex_mem_i_Jump;

    logic [DATA_WIDTH-1:0] ex_mem_o_alu, ex_mem_o_rd2;
    logic              ex_mem_o_zero;
    logic [NB_REG-1:0] ex_mem_o_rd;
    logic [       2:0] ex_mem_o_funct3;
    logic ex_mem_o_RegWrite, ex_mem_o_MemRead;
    logic ex_mem_o_MemWrite, ex_mem_o_MemToReg;
    logic ex_mem_o_Branch, ex_mem_o_Jump;

    EX_MEM_Buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .NB_REG(NB_REG)
    ) u_ex_mem (
        .i_clk        (clk),
        .i_reset      (ex_mem_reset),
        .i_enable     (ex_mem_enable),
        .i_alu_result (ex_mem_i_alu),
        .i_zero       (ex_mem_i_zero),
        .i_read_data_2(ex_mem_i_rd2),
        .i_rd         (ex_mem_i_rd),
        .i_funct3     (ex_mem_i_funct3),
        .i_RegWrite   (ex_mem_i_RegWrite),
        .i_MemRead    (ex_mem_i_MemRead),
        .i_MemWrite   (ex_mem_i_MemWrite),
        .i_MemToReg   (ex_mem_i_MemToReg),
        .i_Branch     (ex_mem_i_Branch),
        .i_Jump       (ex_mem_i_Jump),
        .o_alu_result (ex_mem_o_alu),
        .o_zero       (ex_mem_o_zero),
        .o_read_data_2(ex_mem_o_rd2),
        .o_rd         (ex_mem_o_rd),
        .o_funct3     (ex_mem_o_funct3),
        .o_RegWrite   (ex_mem_o_RegWrite),
        .o_MemRead    (ex_mem_o_MemRead),
        .o_MemWrite   (ex_mem_o_MemWrite),
        .o_MemToReg   (ex_mem_o_MemToReg),
        .o_Branch     (ex_mem_o_Branch),
        .o_Jump       (ex_mem_o_Jump)
    );

    // ================================================================
    // MEM_WB_Buffer
    // ================================================================
    logic mem_wb_reset, mem_wb_enable;
    logic [DATA_WIDTH-1:0] mem_wb_i_alu, mem_wb_i_mem;
    logic [NB_REG-1:0] mem_wb_i_rd;
    logic mem_wb_i_RegWrite, mem_wb_i_MemToReg;

    logic [DATA_WIDTH-1:0] mem_wb_o_alu, mem_wb_o_mem;
    logic [NB_REG-1:0] mem_wb_o_rd;
    logic mem_wb_o_RegWrite, mem_wb_o_MemToReg;

    MEM_WB_Buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .NB_REG(NB_REG)
    ) u_mem_wb (
        .i_clk          (clk),
        .i_reset        (mem_wb_reset),
        .i_enable       (mem_wb_enable),
        .i_alu_result   (mem_wb_i_alu),
        .i_mem_read_data(mem_wb_i_mem),
        .i_rd           (mem_wb_i_rd),
        .i_RegWrite     (mem_wb_i_RegWrite),
        .i_MemToReg     (mem_wb_i_MemToReg),
        .o_alu_result   (mem_wb_o_alu),
        .o_mem_read_data(mem_wb_o_mem),
        .o_rd           (mem_wb_o_rd),
        .o_RegWrite     (mem_wb_o_RegWrite),
        .o_MemToReg     (mem_wb_o_MemToReg)
    );

    // ================================================================
    // Stimulus
    // ================================================================
    initial begin
        // ---------- reset all ----------
        id_ex_reset = 1;
        id_ex_enable = 0;
        id_ex_flush = 0;
        ex_mem_reset = 1;
        ex_mem_enable = 0;
        mem_wb_reset = 1;
        mem_wb_enable = 0;

        id_ex_i_PC = 0;
        id_ex_i_rd1 = 0;
        id_ex_i_rd2 = 0;
        id_ex_i_imm = 0;
        id_ex_i_rs1 = 0;
        id_ex_i_rs2 = 0;
        id_ex_i_rd = 0;
        id_ex_i_funct3 = 0;
        id_ex_i_funct7_5 = 0;
        id_ex_i_ALUSrc = 0;
        id_ex_i_ALUOp = 0;
        id_ex_i_RegWrite = 0;
        id_ex_i_MemRead = 0;
        id_ex_i_MemWrite = 0;
        id_ex_i_MemToReg = 0;
        id_ex_i_Branch = 0;
        id_ex_i_Jump = 0;

        ex_mem_i_alu = 0;
        ex_mem_i_zero = 0;
        ex_mem_i_rd2 = 0;
        ex_mem_i_rd = 0;
        ex_mem_i_funct3 = 0;
        ex_mem_i_RegWrite = 0;
        ex_mem_i_MemRead = 0;
        ex_mem_i_MemWrite = 0;
        ex_mem_i_MemToReg = 0;
        ex_mem_i_Branch = 0;
        ex_mem_i_Jump = 0;

        mem_wb_i_alu = 0;
        mem_wb_i_mem = 0;
        mem_wb_i_rd = 0;
        mem_wb_i_RegWrite = 0;
        mem_wb_i_MemToReg = 0;

        tick();
        id_ex_reset  = 0;
        ex_mem_reset = 0;
        mem_wb_reset = 0;

        // ================================================================
        // Test 1: ID_EX reset outputs are zero
        // ================================================================
        $display("--- ID_EX_Buffer: reset clears outputs ---");
        check("ID_EX PC=0", id_ex_o_PC, 32'h0);
        check("ID_EX rd1=0", id_ex_o_rd1, 32'h0);
        check("ID_EX ctrl=0", {29'h0, id_ex_o_RegWrite, id_ex_o_MemRead, id_ex_o_Jump}, 32'h0);

        // ================================================================
        // Test 2: ID_EX latches data on enable
        // ================================================================
        $display("--- ID_EX_Buffer: latch on enable ---");
        id_ex_i_PC       = 32'h0000_0004;
        id_ex_i_rd1      = 32'hDEAD_BEEF;
        id_ex_i_rd2      = 32'hCAFE_BABE;
        id_ex_i_imm      = 32'hFFFF_FFF0;
        id_ex_i_rd       = 5'd3;
        id_ex_i_funct3   = 3'b000;
        id_ex_i_funct7_5 = 1'b0;
        id_ex_i_ALUSrc   = 1'b1;
        id_ex_i_ALUOp    = 2'b10;
        id_ex_i_RegWrite = 1'b1;
        id_ex_i_MemRead  = 1'b0;
        id_ex_i_MemWrite = 1'b0;
        id_ex_i_MemToReg = 1'b0;
        id_ex_i_Branch   = 1'b0;
        id_ex_i_Jump     = 1'b0;
        id_ex_enable     = 1;
        tick();
        check("ID_EX o_PC", id_ex_o_PC, 32'h0000_0004);
        check("ID_EX o_rd1", id_ex_o_rd1, 32'hDEAD_BEEF);
        check("ID_EX o_rd2", id_ex_o_rd2, 32'hCAFE_BABE);
        check("ID_EX o_imm", id_ex_o_imm, 32'hFFFF_FFF0);
        check("ID_EX o_rd", {27'h0, id_ex_o_rd}, 32'd3);
        check("ID_EX o_ALUSrc", {31'h0, id_ex_o_ALUSrc}, 32'h1);
        check("ID_EX o_ALUOp", {30'h0, id_ex_o_ALUOp}, 32'h2);
        check("ID_EX o_RegWrite", {31'h0, id_ex_o_RegWrite}, 32'h1);

        // ================================================================
        // Test 3: ID_EX holds value when disabled
        // ================================================================
        $display("--- ID_EX_Buffer: hold on disable ---");
        id_ex_enable = 0;
        id_ex_i_PC   = 32'hDEAD_0000;
        id_ex_i_rd1  = 32'h0;
        tick();
        check("ID_EX hold PC", id_ex_o_PC, 32'h0000_0004);
        check("ID_EX hold rd1", id_ex_o_rd1, 32'hDEAD_BEEF);

        // ================================================================
        // Test 4: ID_EX synchronous reset while running
        // ================================================================
        $display("--- ID_EX_Buffer: sync reset clears ---");
        id_ex_reset  = 1;
        id_ex_enable = 1;
        tick();
        check("ID_EX rst PC", id_ex_o_PC, 32'h0);
        check("ID_EX rst rd1", id_ex_o_rd1, 32'h0);
        id_ex_reset = 0;

        // ================================================================
        // Test 5: EX_MEM latches correctly
        // ================================================================
        $display("--- EX_MEM_Buffer: latch on enable ---");
        ex_mem_i_alu      = 32'hABCD_1234;
        ex_mem_i_zero     = 1'b1;
        ex_mem_i_rd2      = 32'h0000_00FF;
        ex_mem_i_rd       = 5'd7;
        ex_mem_i_RegWrite = 1'b1;
        ex_mem_i_MemRead  = 1'b0;
        ex_mem_i_MemWrite = 1'b1;
        ex_mem_i_MemToReg = 1'b0;
        ex_mem_i_Branch   = 1'b0;
        ex_mem_i_Jump     = 1'b0;
        ex_mem_enable     = 1;
        tick();
        check("EX_MEM o_alu", ex_mem_o_alu, 32'hABCD_1234);
        check("EX_MEM o_zero", {31'h0, ex_mem_o_zero}, 32'h1);
        check("EX_MEM o_rd2", ex_mem_o_rd2, 32'h0000_00FF);
        check("EX_MEM o_rd", {27'h0, ex_mem_o_rd}, 32'd7);
        check("EX_MEM o_RegWrite", {31'h0, ex_mem_o_RegWrite}, 32'h1);
        check("EX_MEM o_MemWrite", {31'h0, ex_mem_o_MemWrite}, 32'h1);

        // ================================================================
        // Test 6: EX_MEM synchronous reset
        // ================================================================
        $display("--- EX_MEM_Buffer: sync reset ---");
        ex_mem_reset  = 1;
        ex_mem_enable = 1;
        tick();
        check("EX_MEM rst alu", ex_mem_o_alu, 32'h0);
        check("EX_MEM rst rd", {27'h0, ex_mem_o_rd}, 32'h0);
        ex_mem_reset = 0;

        // ================================================================
        // Test 7: MEM_WB latches correctly
        // ================================================================
        $display("--- MEM_WB_Buffer: latch on enable ---");
        mem_wb_i_alu      = 32'h1234_5678;
        mem_wb_i_mem      = 32'hAABB_CCDD;
        mem_wb_i_rd       = 5'd15;
        mem_wb_i_RegWrite = 1'b1;
        mem_wb_i_MemToReg = 1'b1;
        mem_wb_enable     = 1;
        tick();
        check("MEM_WB o_alu", mem_wb_o_alu, 32'h1234_5678);
        check("MEM_WB o_mem", mem_wb_o_mem, 32'hAABB_CCDD);
        check("MEM_WB o_rd", {27'h0, mem_wb_o_rd}, 32'd15);
        check("MEM_WB o_RegWrite", {31'h0, mem_wb_o_RegWrite}, 32'h1);
        check("MEM_WB o_MemToReg", {31'h0, mem_wb_o_MemToReg}, 32'h1);

        // ================================================================
        // Test 8: MEM_WB synchronous reset
        // ================================================================
        $display("--- MEM_WB_Buffer: sync reset ---");
        mem_wb_reset  = 1;
        mem_wb_enable = 1;
        tick();
        check("MEM_WB rst alu", mem_wb_o_alu, 32'h0);
        check("MEM_WB rst mem", mem_wb_o_mem, 32'h0);
        mem_wb_reset = 0;

        // ================================================================
        // Summary
        // ================================================================
        $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
