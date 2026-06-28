`timescale 1ns / 1ps

// Integration test: IF through WB, no data hazards (NOPs pad all dependencies).
// Test program loads x1=10, x2=3 via ADDI, then runs ADD/AND/OR/SUB with enough
// NOPs between instructions so no forwarding is needed.
// Expected results: x3=13, x4=2, x5=11, x6=7.
module tb_IF_to_WB;

    // ----------------------------------------------------------------
    // DUT parameters
    // ----------------------------------------------------------------
    localparam NB_PC = 32;
    localparam NB_INST = 32;
    localparam NB_REG = 5;
    localparam DATA_WIDTH = 32;
    localparam NB_ADDR = 8;

    // ----------------------------------------------------------------
    // DUT ports
    // ----------------------------------------------------------------
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

    // ----------------------------------------------------------------
    // Clock
    // ----------------------------------------------------------------
    initial i_clk = 0;
    always #5 i_clk = ~i_clk;

    task tick;
        @(posedge i_clk);
        #1;
    endtask

    // ----------------------------------------------------------------
    // Program load helper: write one instruction word to imem
    // ----------------------------------------------------------------
    task load_instr(input [NB_ADDR-1:0] addr, input [NB_INST-1:0] instr);
        @(negedge i_clk);
        i_imem_wr   = 1;
        i_imem_addr = addr;
        i_imem_data = instr;
        @(posedge i_clk);
        #1;
        i_imem_wr = 0;
    endtask

    // ----------------------------------------------------------------
    // Test program (NOP-padded, no data hazards)
    //   addi x1, x0, 10   -> x1 = 10
    //   nop × 3
    //   addi x2, x0, 3    -> x2 = 3
    //   nop × 3
    //   add  x3, x1, x2   -> x3 = 13
    //   nop × 3
    //   and  x4, x1, x2   -> x4 = 10 & 3 = 2
    //   nop × 3
    //   or   x5, x1, x2   -> x5 = 10 | 3 = 11
    //   nop × 3
    //   sub  x6, x1, x2   -> x6 = 10 - 3 = 7
    // ----------------------------------------------------------------
    localparam [NB_INST-1:0] ADDI_X1_X0_10 = 32'h00A00093;
    localparam [NB_INST-1:0] ADDI_X2_X0_3 = 32'h00300113;
    localparam [NB_INST-1:0] NOP = 32'h00000013;
    localparam [NB_INST-1:0] ADD_X3_X1_X2 = 32'h002081B3;
    localparam [NB_INST-1:0] AND_X4_X1_X2 = 32'h0020F233;
    localparam [NB_INST-1:0] OR_X5_X1_X2 = 32'h0020E2B3;
    localparam [NB_INST-1:0] SUB_X6_X1_X2 = 32'h40208333;

    // ----------------------------------------------------------------
    // Test bookkeeping
    // ----------------------------------------------------------------
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

    // ----------------------------------------------------------------
    // Main
    // ----------------------------------------------------------------
    initial begin
        pass_count  = 0;
        fail_count  = 0;
        i_imem_wr   = 0;
        i_imem_addr = '0;
        i_imem_data = '0;

        // Reset: hold for 2 cycles with IF frozen
        i_reset     = 1;
        i_if_enable = 0;
        tick;
        tick;
        i_reset = 0;

        // Load program while PC is still frozen
        load_instr(8'h00, ADDI_X1_X0_10);
        load_instr(8'h01, NOP);
        load_instr(8'h02, NOP);
        load_instr(8'h03, NOP);
        load_instr(8'h04, ADDI_X2_X0_3);
        load_instr(8'h05, NOP);
        load_instr(8'h06, NOP);
        load_instr(8'h07, NOP);
        load_instr(8'h08, ADD_X3_X1_X2);
        load_instr(8'h09, NOP);
        load_instr(8'h0A, NOP);
        load_instr(8'h0B, NOP);
        load_instr(8'h0C, AND_X4_X1_X2);
        load_instr(8'h0D, NOP);
        load_instr(8'h0E, NOP);
        load_instr(8'h0F, NOP);
        load_instr(8'h10, OR_X5_X1_X2);
        load_instr(8'h11, NOP);
        load_instr(8'h12, NOP);
        load_instr(8'h13, NOP);
        load_instr(8'h14, SUB_X6_X1_X2);

        // Enable pipeline — let all instructions reach WB
        i_if_enable = 1;
        repeat (40) tick;

        // Check register file via hierarchical access
        $display("--- Stage 6: full pipeline (no hazards) ---");
        check("x1 = 10", DUT.ID.RF.r_RF[1], 32'd10);
        check("x2 =  3", DUT.ID.RF.r_RF[2], 32'd3);
        check("x3 = 13 (ADD)", DUT.ID.RF.r_RF[3], 32'd13);
        check("x4 =  2 (AND)", DUT.ID.RF.r_RF[4], 32'd2);
        check("x5 = 11 (OR)", DUT.ID.RF.r_RF[5], 32'd11);
        check("x6 =  7 (SUB)", DUT.ID.RF.r_RF[6], 32'd7);

        $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
