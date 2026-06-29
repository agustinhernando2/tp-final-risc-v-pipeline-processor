`timescale 1ns / 1ps
//
// Testbench template — copy and fill in the marked sections.
// Combinational DUTs: remove the clock block and tick task.
// Sequential DUTs   : keep them and drive inputs before tick().
//

module tb_<ModuleName>;

    // ----------------------------------------------------------------
    // Parameters
    // ----------------------------------------------------------------
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10;     // remove if combinational

    // ----------------------------------------------------------------
    // Signals
    // ----------------------------------------------------------------
    logic                   clk;    // remove if combinational
    logic                   reset;  // remove if combinational
    // <add DUT-specific ports here>

    int pass_count;
    int fail_count;

    // ----------------------------------------------------------------
    // DUT
    // ----------------------------------------------------------------
    <ModuleName> #(
        .DATA_WIDTH(DATA_WIDTH)
    ) DUT (
        .i_clk   (clk),            // remove if combinational
        .i_reset (reset)            // remove if combinational
        // <wire remaining ports>
    );

    // ----------------------------------------------------------------
    // Clock — remove this block for combinational DUTs
    // ----------------------------------------------------------------
    always #(CLK_PERIOD / 2) clk = ~clk;

    // ----------------------------------------------------------------
    // Tasks
    // ----------------------------------------------------------------

    // Assert a single value. Works for any width up to DATA_WIDTH.
    task automatic check(input string label,
                         input logic [DATA_WIDTH-1:0] got, expected);
        if (got === expected) begin
            $display("  PASS  %s: 0x%08h", label, got);
            pass_count++;
        end else begin
            $display("  FAIL  %s: expected 0x%08h, got 0x%08h", label, expected, got);
            fail_count++;
        end
    endtask

    // Advance one clock and wait 1 ns for combinational outputs to settle.
    // Remove for combinational DUTs.
    task automatic tick();
        @(posedge clk);
        #1;
    endtask

    // ----------------------------------------------------------------
    // Stimulus
    // ----------------------------------------------------------------
    initial begin
        // --- initialise ---
        clk        = 0;             // remove if combinational
        reset      = 1;             // remove if combinational
        pass_count = 0;
        fail_count = 0;
        // <set remaining inputs to safe defaults>

        // --- release reset (sequential only) ---
        tick();
        reset = 0;

        // ----------------------------------------------------------------
        // Test group: <description>
        // ----------------------------------------------------------------
        $display("--- <description> ---");
        // <drive inputs>
        #1;                         // replace with tick() for sequential
        check("<label>", /* got */ , /* expected */ );

        // ----------------------------------------------------------------
        // Summary — do not modify this block
        // ----------------------------------------------------------------
        $display("\n--- Results: %0d passed, %0d failed ---", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
