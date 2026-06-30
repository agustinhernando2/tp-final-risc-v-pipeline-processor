`timescale 1ns / 1ps

// Integration test: taken branch under STEP-BY-STEP execution (Regression BUG-003).
//
// In step-by-step debug the DebugUnit pulses the master enable (i_if_enable) for one
// cycle per step and freezes the pipeline (enable=0) for many cycles while it dumps
// state over UART. A taken branch resolves in MEM and "waits" in EX/MEM driving
// PCSrc until the next enabled cycle redirects the PC. If the EX/MEM flush is NOT
// gated by i_if_enable, the branch is evicted from EX/MEM during the frozen dump,
// PCSrc drops before the (enable-gated) PC redirect fires, and the branch target is
// flushed but never re-fetched.
//
// This testbench EMULATES step mode (one enabled cycle, then FREEZE frozen cycles)
// without the UART/DebugUnit, so the regression is deterministic.
//
// Program (same as tb_branch Test 3 plus a target body):
//   0: addi x1, x0, 5
//   1: addi x2, x0, 5
//   2: beq  x1, x2, +12   # taken; target = byte 8 + 12 = byte 20 = instr 5
//   3: addi x10, x0, 123  # B+4 -> flushed
//   4: addi x11, x0, 200  # B+8 -> flushed
//   5: addi x8,  x0, 3    # branch target body (must run -> x8 = 3)
//   6: halt
module tb_step_branch;

    localparam NB_PC = 32, NB_INST = 32, NB_REG = 5, DATA_WIDTH = 32, NB_ADDR = 8;
    localparam FREEZE = 4;  // cycles frozen between steps (emulates the dump)

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

    // one "step": enable for exactly one cycle, then freeze for FREEZE cycles.
    task step;
        i_if_enable = 1;
        tick;
        i_if_enable = 0;
        repeat (FREEZE) tick;
    endtask

    int pass_count, fail_count;
    task check(input string name, input logic [DATA_WIDTH-1:0] got,
               input logic [DATA_WIDTH-1:0] expected);
        if (got === expected) begin
            $display("  PASS  %s: %0d", name, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s: got %0d, expected %0d", name, got, expected);
            fail_count++;
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        i_imem_wr = 0;
        i_imem_addr = '0;
        i_imem_data = '0;
        i_if_enable = 0;

        i_reset = 1;
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
        load_instr(8'h05, 32'h00300413);  // addi x8,  x0, 3   (target body)
        load_instr(8'h06, 32'h0000000b);  // halt

        $display("--- Taken branch in STEP-BY-STEP (freeze=%0d) ---", FREEZE);
        repeat (20) step;

        // Target must run despite the per-step freeze; B+4/B+8 must stay flushed.
        check("STEP: x8 == 3 (branch target re-fetched)", DUT.ID.RF.r_RF[8], 32'd3);
        check("STEP: x10 == 0 (B+4 flushed)", DUT.ID.RF.r_RF[10], 32'd0);
        check("STEP: x11 == 0 (B+8 flushed)", DUT.ID.RF.r_RF[11], 32'd0);

        $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end

endmodule
