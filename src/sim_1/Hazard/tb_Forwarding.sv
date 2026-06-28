`timescale 1ns / 1ps

// Stage 7 test: forwarding and load-use hazard detection.
//
// Test A — back-to-back RAW hazards (EX and MEM/WB forwarding):
//   I0: addi x1, x0, 10   -> x1 = 10
//   I1: addi x2, x1,  3   -> x2 = 13  (EX/MEM forward: x1 from I0)
//   I2: add  x3, x1, x2   -> x3 = 23  (MEM/WB fwd: x1; EX/MEM fwd: x2 from I1)
//   I3: sub  x4, x3, x1   -> x4 = 13  (EX/MEM fwd: x3; x1 already in reg file)
//
// Test B — load-use hazard (1-cycle stall + MEM/WB forward):
//   I4: sw   x1, 0(x0)    -> MEM[0] = 10
//   I5: lw   x5, 0(x0)    -> x5 = 10
//   I6: add  x6, x5, x2   -> x6 = 23  (MEM/WB fwd: x5 after stall; x2 = 13 from reg)
//   I7: sub  x7, x3, x2   -> x7 = 10  (no forwarding needed; x3=23, x2=13 in reg file)
module tb_Forwarding;

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

    // Test A: back-to-back RAW hazards
    localparam [NB_INST-1:0] ADDI_X1_X0_10 = 32'h00A00093;  // addi x1, x0, 10
    localparam [NB_INST-1:0] ADDI_X2_X1_3 = 32'h00308113;  // addi x2, x1, 3
    localparam [NB_INST-1:0] ADD_X3_X1_X2 = 32'h002081B3;  // add  x3, x1, x2
    localparam [NB_INST-1:0] SUB_X4_X3_X1 = 32'h40118233;  // sub  x4, x3, x1
    // Test B: load-use hazard
    localparam [NB_INST-1:0] SW_X1_0_X0 = 32'h00102023;  // sw   x1, 0(x0)
    localparam [NB_INST-1:0] LW_X5_0_X0 = 32'h00002283;  // lw   x5, 0(x0)
    localparam [NB_INST-1:0] ADD_X6_X5_X2 = 32'h00228333;  // add  x6, x5, x2
    localparam [NB_INST-1:0] SUB_X7_X3_X2 = 32'h402183B3;  // sub  x7, x3, x2

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

    initial begin
        pass_count  = 0;
        fail_count  = 0;
        i_imem_wr   = 0;
        i_imem_addr = '0;
        i_imem_data = '0;

        i_reset     = 1;
        i_if_enable = 0;
        tick;
        tick;
        i_reset = 0;

        // Load test program
        load_instr(8'h00, ADDI_X1_X0_10);
        load_instr(8'h01, ADDI_X2_X1_3);
        load_instr(8'h02, ADD_X3_X1_X2);
        load_instr(8'h03, SUB_X4_X3_X1);
        load_instr(8'h04, SW_X1_0_X0);
        load_instr(8'h05, LW_X5_0_X0);
        load_instr(8'h06, ADD_X6_X5_X2);
        load_instr(8'h07, SUB_X7_X3_X2);

        // Run pipeline
        i_if_enable = 1;
        repeat (30) tick;

        // --- Test A: EX forwarding ---
        $display("--- Test A: back-to-back RAW hazards (forwarding) ---");
        check("x1 = 10 (addi x1, x0, 10)", DUT.ID.RF.r_RF[1], 32'd10);
        check("x2 = 13 (addi x2, x1, 3)", DUT.ID.RF.r_RF[2], 32'd13);
        check("x3 = 23 (add  x3, x1, x2)", DUT.ID.RF.r_RF[3], 32'd23);
        check("x4 = 13 (sub  x4, x3, x1)", DUT.ID.RF.r_RF[4], 32'd13);

        // --- Test B: load-use hazard ---
        $display("--- Test B: load-use hazard (1-cycle stall) ---");
        check("x5 = 10 (lw x5, 0(x0))", DUT.ID.RF.r_RF[5], 32'd10);
        check("x6 = 23 (add x6, x5, x2)", DUT.ID.RF.r_RF[6], 32'd23);
        check("x7 = 10 (sub x7, x3, x2)", DUT.ID.RF.r_RF[7], 32'd10);

        $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
